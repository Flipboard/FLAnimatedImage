//
//  FLAnimatedImageFrameCache.m
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLAnimatedImageFrameCache.h"

#import <pthread.h>

#import "FLWeakProxy.h"
#import "FLAnimatedImage.h"
#import "FLAnimatedImageFrameDataSource.h"

#define MEGABYTE (1024 * 1024)

// An animated image's data size (dimensions * frameCount) category; its value is the max allowed memory (in MB).
// E.g.: A 100x200px GIF with 30 frames is ~2.3MB in our pixel format and would fall into the `FLAnimatedImageDataSizeCategoryAll` category.
typedef NS_ENUM(NSUInteger, FLAnimatedImageDataSizeCategory) {
    FLAnimatedImageDataSizeCategoryAll = 10,       // All frames permanently in memory (be nice to the CPU)
    FLAnimatedImageDataSizeCategoryDefault = 75,   // A frame cache of default size in memory (usually real-time performance and keeping low memory profile)
    FLAnimatedImageDataSizeCategoryOnDemand = 250, // Only keep one frame at the time in memory (easier on memory, slowest performance)
    FLAnimatedImageDataSizeCategoryUnsupported     // Even for one frame too large, computer says no.
};

typedef NS_ENUM(NSUInteger, FLAnimatedImageFrameCacheSize) {
    FLAnimatedImageFrameCacheSizeNoLimit = 0,                // 0 means no specific limit
    FLAnimatedImageFrameCacheSizeLowMemory = 1,              // The minimum frame cache size; this will produce frames on-demand.
    FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning = 2, // If we can produce the frames faster than we consume, one frame ahead will already result in a stutter-free playback.
    FLAnimatedImageFrameCacheSizeDefault = 5                 // Build up a comfy buffer window to cope with CPU hiccups etc.
};

// For custom dispatching of memory warnings to avoid deallocation races since NSNotificationCenter doesn't retain objects it is notifying.
static NSHashTable *allAnimatedImagesWeak;

@implementation FLAnimatedImageFrameCache
{
    NSUInteger _requestedFrameIndex;
    NSMutableIndexSet *_cachedFrameIndexes;
    NSMutableIndexSet *_requestedFrameIndexes;
    // Don't set this ivar directly, instead use `setCachedFramesForIndexes`, which acquires
    // a necessary lock before modifying it.
    // Don't read this ivar without locking `_cachedFramesMutex` unless your
    // code is guaranteed to run on the main thread.
    NSDictionary *_cachedFramesForIndexes;
    NSUInteger _frameCacheSizeMaxInternal;
    NSUInteger _memoryWarningCount;

    NSUInteger _frameCount;
    NSUInteger _frameCacheSizeOptimal;
    NSUInteger _posterImageFrameIndex;
    NSIndexSet *_allFramesIndexSet;

    dispatch_queue_t _serialQueue;

    FLAnimatedImageFrameCache *_weakProxy;

    id<FLAnimatedImageFrameDataSource> _dataSource;

    pthread_mutex_t _cachedFramesMutex;
}

+ (void)initialize
{
    if (self == [FLAnimatedImageFrameCache class]) {
        // UIKit memory warning notification handler shared by all of the instances
        allAnimatedImagesWeak = [NSHashTable weakObjectsHashTable];

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            // UIKit notifications are posted on the main thread. didReceiveMemoryWarning: is expecting the main run loop, and we don't lock on allAnimatedImagesWeak
            NSAssert([NSThread isMainThread], @"Received memory warning on non-main thread");
            // Get a strong reference to all of the images. If an instance is returned in this array, it is still live and has not entered dealloc.
            // Note that FLAnimatedImages can be created on any thread, so the hash table must be locked.
            NSArray *images = nil;
            @synchronized(allAnimatedImagesWeak) {
                images = [[allAnimatedImagesWeak allObjects] copy];
            }
            // Now issue notifications to all of the images while holding a strong reference to them
            [images makeObjectsPerformSelector:@selector(didReceiveMemoryWarning:) withObject:note];
        }];
    }
}

+ (void)registerInstanceOfClassForMemoryWarnings:(FLAnimatedImageFrameCache *)animatedImage
{
    // Register this instance in the weak table for memory notifications. The NSHashTable will clean up after itself when we're gone.
    // Note that FLAnimatedImages can be created on any thread, so the hash table must be locked.
    @synchronized(allAnimatedImagesWeak) {
        [allAnimatedImagesWeak addObject:animatedImage];
    }
}

#pragma mark - Life Cycle

- (instancetype)initWithFrameCount:(NSUInteger)frameCount
                 skippedFrameCount:(NSUInteger)skippedFrameCount
                         frameSize:(CGFloat)frameSize
                       posterImage:(UIImage *)posterImage
                  posterImageIndex:(NSUInteger)posterImageIndex
                        dataSource:(id<FLAnimatedImageFrameDataSource>)dataSource
{
    if (self = [super init]) {
        [[self class] registerInstanceOfClassForMemoryWarnings:self];

        _frameCount = frameCount;

        // Initialize internal data structures
        pthread_mutex_init(&_cachedFramesMutex, NULL);
        NSMutableDictionary *cachedFramesForIndexes = [[NSMutableDictionary alloc] init];
        _cachedFrameIndexes = [[NSMutableIndexSet alloc] init];
        _requestedFrameIndexes = [[NSMutableIndexSet alloc] init];

        _allFramesIndexSet = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, frameCount)];
        [_allFramesIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            if (idx == posterImageIndex) {
                _posterImageFrameIndex = posterImageIndex;
                cachedFramesForIndexes[@(posterImageIndex)] = posterImage;
                [_cachedFrameIndexes addIndex:posterImageIndex];
            }
        }];

        _cachedFramesForIndexes = [cachedFramesForIndexes copy];

        CGFloat animatedImageDataSize = frameSize * (_frameCount - skippedFrameCount) / MEGABYTE;
        if (animatedImageDataSize <= FLAnimatedImageDataSizeCategoryAll) {
            _frameCacheSizeOptimal = _frameCount;
        } else if (animatedImageDataSize <= FLAnimatedImageDataSizeCategoryDefault) {
            // This value doesn't depend on device memory much because if we're not keeping all frames in memory we will always be decoding 1 frame up ahead per 1 frame that gets played and at this point we might as well just keep a small buffer just large enough to keep from running out of frames.
            _frameCacheSizeOptimal = FLAnimatedImageFrameCacheSizeDefault;
        } else {
            // The predicted size exceeds the limits to build up a cache and we go into low memory mode from the beginning.
            _frameCacheSizeOptimal = FLAnimatedImageFrameCacheSizeLowMemory;
        }
        // In any case, cap the optimal cache size at the frame count.
        _frameCacheSizeOptimal = MIN(_frameCacheSizeOptimal, _frameCount);

        _dataSource = dataSource;
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_cachedFramesMutex);

    if (_weakProxy) {
        [NSObject cancelPreviousPerformRequestsWithTarget:_weakProxy];
    }
}

#pragma mark - Public Methods

- (UIImage *)posterImage
{
    // Grab the lock in case this is being called off the main thread.
    pthread_mutex_lock(&_cachedFramesMutex);
    UIImage *posterImage = _cachedFramesForIndexes[@(_posterImageFrameIndex)];
    pthread_mutex_unlock(&_cachedFramesMutex);
    return posterImage;
}

- (id<FLAnimatedImageFrameDataSource>)dataSource
{
    return _dataSource;
}

- (UIImage *)cachedImageAtIndex:(NSUInteger)index
{
    // Early return if the requested index is beyond bounds.
    // Note: We're comparing an index with a count and need to bail on greater than or equal to.
    if (index >= _frameCount) {
        FLLogWarn(@"Skipping requested frame %lu beyond bounds (total frame count: %lu) for animated image: %@", (unsigned long)index, (unsigned long)_frameCount, self);
        return nil;
    }
    
    // Remember requested frame index, this influences what we should cache next.
    _requestedFrameIndex = index;
#if defined(DEBUG) && DEBUG
    if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImage:didRequestCachedFrame:)]) {
        [self.debug_delegate debug_animatedImage:nil didRequestCachedFrame:index];
    }
#endif
    
    // Quick check to avoid doing any work if we already have all possible frames cached, a common case.
    if ([_cachedFrameIndexes count] < _frameCount) {
        // If we have frames that should be cached but aren't and aren't requested yet, request them.
        // Exclude existing cached frames, frames already requested, and specially cached poster image.
        NSMutableIndexSet *frameIndexesToAddToCacheMutable = [[self frameIndexesToCache] mutableCopy];
        [frameIndexesToAddToCacheMutable removeIndexes:_cachedFrameIndexes];
        [frameIndexesToAddToCacheMutable removeIndexes:_requestedFrameIndexes];
        [frameIndexesToAddToCacheMutable removeIndex:_posterImageFrameIndex];
        NSIndexSet *frameIndexesToAddToCache = [frameIndexesToAddToCacheMutable copy];
        
        // Asynchronously add frames to our cache.
        if ([frameIndexesToAddToCache count] > 0) {
            [self addFrameIndexesToCache:frameIndexesToAddToCache];
        }
    }
    
    // Get the specified image.
    // Grab the lock in case this is being called off the main thread.
    pthread_mutex_lock(&_cachedFramesMutex);
    UIImage *image = _cachedFramesForIndexes[@(index)];
    pthread_mutex_unlock(&_cachedFramesMutex);
    
    // Purge if needed based on the current playhead position.
    [self purgeFrameCacheIfNeeded];
    
    return image;
}

#pragma mark - Private Properties

- (FLAnimatedImageFrameCache *)weakProxy
{
    if (!_weakProxy) {
        _weakProxy = (id)[FLWeakProxy weakProxyForObject:self];
    }

    return _weakProxy;
}

- (NSUInteger)frameCacheSizeCurrent
{
    NSUInteger frameCacheSizeCurrent = _frameCacheSizeOptimal;
    
    // If set, respect the caps.
    if (_frameCacheSizeMax > FLAnimatedImageFrameCacheSizeNoLimit) {
        frameCacheSizeCurrent = MIN(frameCacheSizeCurrent, _frameCacheSizeMax);
    }
    
    if (_frameCacheSizeMaxInternal > FLAnimatedImageFrameCacheSizeNoLimit) {
        frameCacheSizeCurrent = MIN(frameCacheSizeCurrent, _frameCacheSizeMaxInternal);
    }
    
    return frameCacheSizeCurrent;
}

- (void)setFrameCacheSizeMaxInternal:(NSUInteger)frameCacheSizeMaxInternal
{
    if (_frameCacheSizeMaxInternal != frameCacheSizeMaxInternal) {
        
        // Remember whether the new cap will cause the current cache size to shrink; then we'll make sure to purge from the cache if needed.
        BOOL willFrameCacheSizeShrink = (frameCacheSizeMaxInternal < self.frameCacheSizeCurrent);
        
        // Update the value
        _frameCacheSizeMaxInternal = frameCacheSizeMaxInternal;
        
        if (willFrameCacheSizeShrink) {
            [self purgeFrameCacheIfNeeded];
        }
    }
}

- (void)setCachedFramesForIndexes:(NSDictionary *)cachedFramesForIndexes
{
    pthread_mutex_lock(&_cachedFramesMutex);
    if (_cachedFramesForIndexes != cachedFramesForIndexes) {
        _cachedFramesForIndexes = [cachedFramesForIndexes copy];
    }
    pthread_mutex_unlock(&_cachedFramesMutex);
}

#pragma mark - Frame Caching

- (NSIndexSet *)frameIndexesToCache
{
    NSIndexSet *indexesToCache = nil;
    // Quick check to avoid building the index set if the number of frames to cache equals the total frame count.
    if (self.frameCacheSizeCurrent == _frameCount) {
        indexesToCache = _allFramesIndexSet;
    } else {
        NSMutableIndexSet *indexesToCacheMutable = [[NSMutableIndexSet alloc] init];
        
        // Add indexes to the set in two separate blocks- the first starting from the requested frame index, up to the limit or the end.
        // The second, if needed, the remaining number of frames beginning at index zero.
        NSUInteger firstLength = MIN(self.frameCacheSizeCurrent, _frameCount - _requestedFrameIndex);
        NSRange firstRange = NSMakeRange(_requestedFrameIndex, firstLength);
        [indexesToCacheMutable addIndexesInRange:firstRange];
        NSUInteger secondLength = self.frameCacheSizeCurrent - firstLength;
        if (secondLength > 0) {
            NSRange secondRange = NSMakeRange(0, secondLength);
            [indexesToCacheMutable addIndexesInRange:secondRange];
        }
        // Double check our math, before we add the poster image index which may increase it by one.
        if ([indexesToCacheMutable count] != self.frameCacheSizeCurrent) {
            FLLogWarn(@"Number of frames to cache doesn't equal expected cache size.");
        }
        
        [indexesToCacheMutable addIndex:_posterImageFrameIndex];
        
        indexesToCache = [indexesToCacheMutable copy];
    }
    
    return indexesToCache;
}

// Only called once from `-cachedImageAtIndex:` but factored into its own method for logical grouping.
- (void)addFrameIndexesToCache:(NSIndexSet *)frameIndexesToAddToCache
{
    // Order matters. First, iterate over the indexes starting from the requested frame index.
    // Then, if there are any indexes before the requested frame index, do those.
    NSRange firstRange = NSMakeRange(_requestedFrameIndex, _frameCount - _requestedFrameIndex);
    NSRange secondRange = NSMakeRange(0, _requestedFrameIndex);
    if (firstRange.length + secondRange.length != _frameCount) {
        FLLogWarn(@"Two-part frame cache range doesn't equal full range.");
    }
    
    // Add to the requested list before we actually kick them off, so they don't get into the queue twice.
    [_requestedFrameIndexes addIndexes:frameIndexesToAddToCache];
    
    // Lazily create dedicated isolation queue.
    if (!_serialQueue) {
        _serialQueue = dispatch_queue_create("com.flipboard.framecachingqueue", DISPATCH_QUEUE_SERIAL);
    }
    
    // Start streaming requested frames in the background into the cache.
    // Avoid capturing self in the block as there's no reason to keep doing work if the animated image went away.
    FLAnimatedImageFrameCache * __weak weakSelf = self;
    dispatch_async(_serialQueue, ^{
        // Produce and cache next needed frame.
        void (^frameRangeBlock)(NSRange, BOOL *) = ^(NSRange range, BOOL *stop) {
            UIImage *previousImage = nil;
            // Iterate through contiguous indexes; can be faster than `enumerateIndexesInRange:options:usingBlock:`.
            for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
                FLAnimatedImageFrameCache *strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }

#if defined(DEBUG) && DEBUG
                CFTimeInterval predrawBeginTime = CACurrentMediaTime();
#endif

                UIImage *image = [strongSelf.dataSource imageAtIndex:i];
                if ([strongSelf.dataSource frameRequiresBlendingWithPreviousFrame:i]) {
                    if (previousImage == nil) {
                        previousImage = [strongSelf synchronousImageAtIndex:i - 1];
                    }
                    image = [strongSelf.dataSource blendImage:image atIndex:i withPreviousImage:previousImage];
                }
                previousImage = image;

#if defined(DEBUG) && DEBUG
                CFTimeInterval predrawDuration = CACurrentMediaTime() - predrawBeginTime;
                CFTimeInterval slowdownDuration = 0.0;
                if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImagePredrawingSlowdownFactor:)]) {
                    CGFloat predrawingSlowdownFactor = [self.debug_delegate debug_animatedImagePredrawingSlowdownFactor:nil];
                    slowdownDuration = predrawDuration * predrawingSlowdownFactor - predrawDuration;
                    [NSThread sleepForTimeInterval:slowdownDuration];
                }
                FLLogVerbose(@"Predrew frame %lu in %f ms for animated image: %@", (unsigned long)i, (predrawDuration + slowdownDuration) * 1000, self);
#endif
                // The results get returned one by one as soon as they're ready (and not in batch).
                // The benefits of having the first frames as quick as possible outweigh building up a buffer to cope with potential hiccups when the CPU suddenly gets busy.
                if (image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [strongSelf cacheFrame:image atIndex:i];
#if defined(DEBUG) && DEBUG
                        if ([weakSelf.debug_delegate respondsToSelector:@selector(debug_animatedImage:didUpdateCachedFrames:)]) {
                            [weakSelf.debug_delegate debug_animatedImage:nil didUpdateCachedFrames:strongSelf->_cachedFrameIndexes];
                        }
#endif
                    });
                }
            }
        };
        
        [frameIndexesToAddToCache enumerateRangesInRange:firstRange options:0 usingBlock:frameRangeBlock];
        [frameIndexesToAddToCache enumerateRangesInRange:secondRange options:0 usingBlock:frameRangeBlock];
    });
}

/**
 * This must be called on the main thread.
 */
- (void)cacheFrame:(UIImage *)image atIndex:(NSUInteger)index
{
    NSAssert([NSThread isMainThread], @"This method must be called on the main thread");

    NSMutableDictionary *mutableCachedFramesForIndexes = [_cachedFramesForIndexes mutableCopy];
    mutableCachedFramesForIndexes[@(index)] = image;
    [self setCachedFramesForIndexes:mutableCachedFramesForIndexes];
    [_cachedFrameIndexes addIndex:index];
    [_requestedFrameIndexes removeIndex:index];
}

// This method is called on _serialQueue. Renders the image at index `i`, taking
// blending with previous frames into account.
- (UIImage *)synchronousImageAtIndex:(NSUInteger)index
{
    // Lock _cachedFramesMutex since we are reading from it, and it could be concurrently being modified
    // on the main thread.
    pthread_mutex_lock(&_cachedFramesMutex);
    UIImage *image = _cachedFramesForIndexes[@(index)];
    pthread_mutex_unlock(&_cachedFramesMutex);

    if (image) {
        return image;
    }

    // Hopefully we won't hit the code path often, as it will be expensive if for frame N
    // we need to render frames [0-(N-1)]. It is possible we'll hit this for particularly large
    // images, or after a memory warning.
    // TODO: Look into always caching (_requestedFrameIndex - 1) to reduce the likelihood of
    // running into this code path.
    image = [self.dataSource imageAtIndex:index];
    if ([self.dataSource frameRequiresBlendingWithPreviousFrame:index]) {
        UIImage *previousImage = [self synchronousImageAtIndex:index - 1];
        image = [self.dataSource blendImage:image atIndex:index withPreviousImage:previousImage];
    }
    return image;
}

- (void)purgeFrameCacheIfNeeded
{
    // Purge frames that are currently cached but don't need to be.
    // But not if we're still under the number of frames to cache.
    // This way, if all frames are allowed to be cached (the common case), we can skip all the `NSIndexSet` math below.
    if ([_cachedFrameIndexes count] > self.frameCacheSizeCurrent) {
        NSMutableIndexSet *indexesToPurge = [_cachedFrameIndexes mutableCopy];
        [indexesToPurge removeIndexes:[self frameIndexesToCache]];

        NSMutableDictionary *mutableCachedFramesForIndexes = [_cachedFramesForIndexes mutableCopy];
        [indexesToPurge enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
            // Iterate through contiguous indexes; can be faster than `enumerateIndexesInRange:options:usingBlock:`.
            for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
                [_cachedFrameIndexes removeIndex:i];
                [mutableCachedFramesForIndexes removeObjectForKey:@(i)];
                // Note: Don't `CGImageSourceRemoveCacheAtIndex` on the image source for frames that we don't want cached any longer to maintain O(1) time access.
#if defined(DEBUG) && DEBUG
                if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImage:didUpdateCachedFrames:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.debug_delegate debug_animatedImage:nil didUpdateCachedFrames:_cachedFrameIndexes];
                    });
                }
#endif
            }
            [self setCachedFramesForIndexes:mutableCachedFramesForIndexes];
        }];
    }
}

- (void)growFrameCacheSizeAfterMemoryWarning:(NSNumber *)frameCacheSize
{
    self.frameCacheSizeMaxInternal = [frameCacheSize unsignedIntegerValue];
    FLLogDebug(@"Grew frame cache size max to %lu after memory warning for animated image: %@", (unsigned long)_frameCacheSizeMaxInternal, self);
    
    // Schedule resetting the frame cache size max completely after a while.
    const NSTimeInterval kResetDelay = 3.0;
    [self.weakProxy performSelector:@selector(resetFrameCacheSizeMaxInternal) withObject:nil afterDelay:kResetDelay];
}


- (void)resetFrameCacheSizeMaxInternal
{
    self.frameCacheSizeMaxInternal = FLAnimatedImageFrameCacheSizeNoLimit;
    FLLogDebug(@"Reset frame cache size max (current frame cache size: %lu) for animated image: %@", (unsigned long)self.frameCacheSizeCurrent, self);
}


#pragma mark System Memory Warnings Notification Handler

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    _memoryWarningCount++;
    
    // If we were about to grow larger, but got rapped on our knuckles by the system again, cancel.
    [NSObject cancelPreviousPerformRequestsWithTarget:self.weakProxy selector:@selector(growFrameCacheSizeAfterMemoryWarning:) object:@(FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning)];
    [NSObject cancelPreviousPerformRequestsWithTarget:self.weakProxy selector:@selector(resetFrameCacheSizeMaxInternal) object:nil];
    
    // Go down to the minimum and by that implicitly immediately purge from the cache if needed to not get jettisoned by the system and start producing frames on-demand.
    FLLogDebug(@"Attempt setting frame cache size max to %lu (previous was %lu) after memory warning #%lu for animated image: %@", (unsigned long)FLAnimatedImageFrameCacheSizeLowMemory, (unsigned long)_frameCacheSizeMaxInternal, (unsigned long)_memoryWarningCount, self);
    self.frameCacheSizeMaxInternal = FLAnimatedImageFrameCacheSizeLowMemory;
    
    // Schedule growing larger again after a while, but cap our attempts to prevent a periodic sawtooth wave (ramps upward and then sharply drops) of memory usage.
    //
    // [mem]^     (2)   (5)  (6)        1) Loading frames for the first time
    //   (*)|      ,     ,    ,         2) Mem warning #1; purge cache
    //      |     /| (4)/|   /|         3) Grow cache size a bit after a while, if no mem warning occurs
    //      |    / |  _/ | _/ |         4) Try to grow cache size back to optimum after a while, if no mem warning occurs
    //      |(1)/  |_/   |/   |__(7)    5) Mem warning #2; purge cache
    //      |__/   (3)                  6) After repetition of (3) and (4), mem warning #3; purge cache
    //      +---------------------->    7) After 3 mem warnings, stay at minimum cache size
    //                            [t]
    //                                  *) The mem high water mark before we get warned might change for every cycle.
    //
    const NSUInteger kGrowAttemptsMax = 2;
    const NSTimeInterval kGrowDelay = 2.0;
    if ((_memoryWarningCount - 1) <= kGrowAttemptsMax) {
        [self.weakProxy performSelector:@selector(growFrameCacheSizeAfterMemoryWarning:) withObject:@(FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning) afterDelay:kGrowDelay];
    }
    
    // Note: It's not possible to get the level of a memory warning with a public API: http://stackoverflow.com/questions/2915247/iphone-os-memory-warnings-what-do-the-different-levels-mean/2915477#2915477
}

@end
