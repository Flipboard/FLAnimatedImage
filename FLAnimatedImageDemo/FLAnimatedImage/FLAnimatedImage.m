//
//  FLAnimatedImage.m
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) 2013-2014 Flipboard. All rights reserved.
//


#import "FLAnimatedImage.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <CoreGraphics/CoreGraphics.h>


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


@interface FLAnimatedImage ()
{
    // Use old school ivar instead of property for retained non-object types (CF type, dispatch "object") to avoid ARC confusion: http://stackoverflow.com/questions/9684972/strong-property-with-attribute-nsobject-for-a-cf-type-doesnt-retain/9690656#9690656
    CGImageSourceRef _imageSource;
    // Note: Only if the deployment target is iOS 6.0 or higher, dispatch objects are declared as "true objects" and participate in ARC, etc.; See <os/object.h> or https://github.com/AFNetworking/AFNetworking/pull/517 for details.
    dispatch_queue_t _serialQueue;
}

@property (nonatomic, assign, readonly) NSUInteger frameCacheSizeOptimal; // The optimal number of frames to cache based on image size & number of frames; never changes
@property (nonatomic, assign) NSUInteger frameCacheSizeMaxInternal; // Allow to cap the cache size e.g. when memory warnings occur; 0 means no specific limit (default)
@property (nonatomic, assign) NSUInteger requestedFrameIndex; // Most recently requested frame index
@property (nonatomic, assign, readonly) NSUInteger posterImageFrameIndex; // Index of non-purgable poster image; never changes
@property (nonatomic, strong, readonly) NSMutableArray *cachedFrames; // Uncached frame indexes hold `NSNull`
@property (nonatomic, strong, readonly) NSMutableIndexSet *cachedFrameIndexes; // Indexes of cached frames
@property (nonatomic, strong, readonly) NSMutableIndexSet *requestedFrameIndexes; // Indexes of frames that are currently produced in the background
@property (nonatomic, strong, readonly) NSIndexSet *allFramesIndexSet; // Default index set with the full range of indexes; never changes
@property (nonatomic, assign) NSUInteger memoryWarningCount;

// The weak proxy is used to break retain cycles with delayed actions from memory warnings.
// We are lying about the actual type here to gain static type checking and eliminate casts.
// The actual type of the object is `FLWeakProxy`. Lazily instantiated since it is not typically needed.
@property (nonatomic, strong, readonly) FLAnimatedImage *weakProxy;

//data for progressive load
@property NSMutableData * progressiveData;
@property NSURLSessionDataTask * progressiveTask;

@end


@implementation FLAnimatedImage

#pragma mark - Accessors
#pragma mark Public

// This is the definite value the frame cache needs to size itself to.
- (NSUInteger)frameCacheSizeCurrent
{
    NSUInteger frameCacheSizeCurrent = self.frameCacheSizeOptimal;
    
    // If set, respect the caps.
    if (self.frameCacheSizeMax > FLAnimatedImageFrameCacheSizeNoLimit) {
        frameCacheSizeCurrent = MIN(frameCacheSizeCurrent, self.frameCacheSizeMax);
    }
    
    if (self.frameCacheSizeMaxInternal > FLAnimatedImageFrameCacheSizeNoLimit) {
        frameCacheSizeCurrent = MIN(frameCacheSizeCurrent, self.frameCacheSizeMaxInternal);
    }
    
    return frameCacheSizeCurrent;
}


- (void)setFrameCacheSizeMax:(NSUInteger)frameCacheSizeMax
{
    if (_frameCacheSizeMax != frameCacheSizeMax) {
        
        // Remember whether the new cap will cause the current cache size to shrink; then we'll make sure to purge from the cache if needed.
        BOOL willFrameCacheSizeShrink = (frameCacheSizeMax < self.frameCacheSizeCurrent);
        
        // Update the value
        _frameCacheSizeMax = frameCacheSizeMax;
        
        if (willFrameCacheSizeShrink) {
            [self purgeFrameCacheIfNeeded];
        }
    }
}


#pragma mark Private

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


// Explicit synthesizing for `readonly` property with overridden getter.
@synthesize weakProxy = _weakProxy;

- (FLAnimatedImage *)weakProxy
{
    if (!_weakProxy) {
        _weakProxy = (id)[FLWeakProxy weakProxyForObject:self];
    }
    
    return _weakProxy;
}


#pragma mark - Life Cycle

- (id)init
{
    NSLog(@"Error: Use `-initWithAnimatedGIFData:` and supply the animated GIF data as an argument to initialize an object of type `FLAnimatedImage`.");
    return nil;
}


- (instancetype)initWithAnimatedGIFData:(NSData *)data
{
    // Early return if no data supplied!
    BOOL hasData = ([data length] > 0);
    if (!hasData) {
        NSLog(@"Error: No animated GIF data supplied.");
        return nil;
    }
    
    self = [super init];
    if (self) {
        // Do one-time initializations of `readonly` properties directly to ivar to prevent implicit actions and avoid need for private `readwrite` property overrides.
        
        // Keep a strong reference to `data` and expose it read-only publicly.
        // However, we will use the `_imageSource` as handler to the image data throughout our life cycle.
        _data = data;
        
        // Initialize internal data structures
        // We'll fill in the initial `NSNull` values below, when we loop through all frames.
        _cachedFrames = [[NSMutableArray alloc] init];
        _cachedFrameIndexes = [[NSMutableIndexSet alloc] init];
        _requestedFrameIndexes = [[NSMutableIndexSet alloc] init];
        _delayTimes = [[NSMutableArray alloc] init];

        // Note: We could leverage `CGImageSourceCreateWithURL` too to add a second initializer `-initWithAnimatedGIFContentsOfURL:`.
        _imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        // Early return on failure!
        if (!_imageSource) {
            NSLog(@"Error: Failed to `CGImageSourceCreateWithData` for animated GIF data %@", data);
            return nil;
        }
        
        // Early return if not GIF!
        CFStringRef imageSourceContainerType = CGImageSourceGetType(_imageSource);
        BOOL isGIFData = UTTypeConformsTo(imageSourceContainerType, kUTTypeGIF);
        if (!isGIFData) {
            NSLog(@"Error: Supplied data is of type %@ and doesn't seem to be GIF data %@", imageSourceContainerType, data);
            return nil;
        }
        
        [self processFrames];
        
        NSDictionary *imageProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyProperties(_imageSource, NULL);
        if (self.frameCount == 0) {
            NSLog(@"Error: Failed to create any valid frames for GIF with properties %@", imageProperties);
            return nil;
        } else if (self.frameCount == 1) {
            // Warn when we only have a single frame but return a valid GIF.
            NSLog(@"Verbose: Created valid GIF but with only a single frame. Image properties: %@", imageProperties);
        } else {
            // We have multiple frames, rock on!
        }
        
        [self calculateCache];
        
        // System Memory Warnings Notification Handler
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

-(instancetype)initWithURLForProgressiveGIF:(NSURL*)gifURL{
    
    //enfore .gif url's
    if (![[gifURL pathExtension] isEqualToString:@"gif"]) {
        NSLog(@"Error: URL given for progressive load is not a GIF.");
        return nil;
    }
    
    if(self = [super init]){
        // Initialize internal data structures
        // We'll fill in the initial `NSNull` values below, when we loop through all frames.
        _cachedFrames = [[NSMutableArray alloc] init];
        _cachedFrameIndexes = [[NSMutableIndexSet alloc] init];
        _requestedFrameIndexes = [[NSMutableIndexSet alloc] init];
        _delayTimes = [[NSMutableArray alloc] init];
        
        //default of load every 4   frames
        _progressiveLoadFramePeriod = 4;
        
        _posterImage = nil;
        
        //we will need to hold a reference to all data as our incremental image source requires we update with all data
        _progressiveData = [NSMutableData new];
        _data = nil;//not used until completely loaded, at which point read-only
        
        //we create a source for providing progressive data
        _imageSource = CGImageSourceCreateIncremental(nil);
        
        // Early return on failure!
        if (!_imageSource) {
            NSLog(@"Error: Failed to `CGImageSourceCreateIncremental");
            return nil;
        }
        
        //start download immediately, respond on background thread
        NSURLSessionConfiguration * config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        NSURLSession * ses = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue new]];
        NSURLSessionDataTask *task = [ses dataTaskWithURL:gifURL];
        //begin immediately
        [task resume];
        self.progressiveTask = task;
        
        // System Memory Warnings Notification Handler
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_weakProxy) {
        [NSObject cancelPreviousPerformRequestsWithTarget:_weakProxy];
    }
    
    if (_imageSource) {
        CFRelease(_imageSource);
    }
    
    if(_progressiveTask){
        [_progressiveTask cancel];
    }
    
    // Needed for deployment target iOS 5.0
#if ((__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0) || (!defined(__IPHONE_6_0)))
    if (_serialQueue) {
        dispatch_release(_serialQueue);
    }
#endif
}


#pragma mark - Public Methods

// See header for more details.
// Note: both consumer and producer are throttled: consumer by frame timings and producer by the available memory (max buffer window size).
- (UIImage *)imageLazilyCachedAtIndex:(NSUInteger)index
{
    // Early return if the requested index is beyond bounds.
    // Note: We're comparing an index with a count and need to bail on greater than or equal to.
    if (index >= self.frameCount) {
        NSLog(@"Error: Skipping requested frame %lu beyond bounds (total frame count: %lu) for animated image: %@", (unsigned long)index,  (unsigned long)self.frameCount, self);
        return nil;
    }
    
    // Remember requested frame index, this influences what we should cache next.
    self.requestedFrameIndex = index;
#if DEBUG
    if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImage:didRequestCachedFrame:)]) {
        [self.debug_delegate debug_animatedImage:self didRequestCachedFrame:index];
    }
#endif
    
    // Quick check to avoid doing any work if we already have all possible frames cached, a common case.
    if ([self.cachedFrameIndexes count] < self.frameCount) {
        // If we have frames that should be cached but aren't and aren't requested yet, request them.
        // Exclude existing cached frames, frames already requested, and specially cached poster image.
        NSMutableIndexSet *frameIndexesToAddToCacheMutable = [[self frameIndexesToCache] mutableCopy];
        [frameIndexesToAddToCacheMutable removeIndexes:self.cachedFrameIndexes];
        [frameIndexesToAddToCacheMutable removeIndexes:self.requestedFrameIndexes];
        [frameIndexesToAddToCacheMutable removeIndex:self.posterImageFrameIndex];
        NSIndexSet *frameIndexesToAddToCache = [frameIndexesToAddToCacheMutable copy];
        
        // Asynchronously add frames to our cache.
        if ([frameIndexesToAddToCache count] > 0) {
            [self addFrameIndexesToCache:frameIndexesToAddToCache];
        }
    }
    
    // Get the specified image. Watch out for `NSNull` placeholders.
    UIImage *image = nil;
    id tryImage = self.cachedFrames[index];
    if ([tryImage isKindOfClass:[UIImage class]]) {
        image = tryImage;
    }
    
    // Purge if needed based on the current playhead position.
    [self purgeFrameCacheIfNeeded];
    
    return image;
}


// Only called once from `-imageLazilyCachedAtIndex` but factored into its own method for logical grouping.
- (void)addFrameIndexesToCache:(NSIndexSet *)frameIndexesToAddToCache
{
    // Order matters. First, iterate over the indexes starting from the requested frame index.
    // Then, if there are any indexes before the requested frame index, do those.
    NSRange firstRange = NSMakeRange(self.requestedFrameIndex, self.frameCount - self.requestedFrameIndex);
    NSRange secondRange = NSMakeRange(0, self.requestedFrameIndex);
    if (firstRange.length + secondRange.length != self.frameCount) {
        NSLog(@"Error: Two-part frame cache range doesn't equal full range.");
    }
    
    // Add to the requested list before we actually kick them off, so they don't get into the queue twice.
    [self.requestedFrameIndexes addIndexes:frameIndexesToAddToCache];
    
    // Lazily create dedicated isolation queue.
    if (!_serialQueue) {
        _serialQueue = dispatch_queue_create("com.flipboard.framecachingqueue", DISPATCH_QUEUE_SERIAL);
    }
    
    // Start streaming requested frames in the background into the cache.
    dispatch_async(_serialQueue, ^{
        // Produce and cache next needed frame.
        void (^frameRangeBlock)(NSRange, BOOL *) = ^(NSRange range, BOOL *stop) {
            // Iterate through contiguous indexes; can be faster than `enumerateIndexesInRange:options:usingBlock:`.
            for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
#if DEBUG
                CFTimeInterval predrawBeginTime = CACurrentMediaTime();
#endif
                UIImage *image = [self predrawnImageAtIndex:i];
#if DEBUG
                CFTimeInterval predrawDuration = CACurrentMediaTime() - predrawBeginTime;
                CFTimeInterval slowdownDuration = 0.0;
                if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImagePredrawingSlowdownFactor:)]) {
                    CGFloat predrawingSlowdownFactor = [self.debug_delegate debug_animatedImagePredrawingSlowdownFactor:self];
                    slowdownDuration = predrawDuration * predrawingSlowdownFactor - predrawDuration;
                    [NSThread sleepForTimeInterval:slowdownDuration];
                }
                //NSLog(@"Verbose: Predrew frame %d in %f ms for animated image: %@", i, (predrawDuration + slowdownDuration) * 1000, self);
#endif
                // The results get returned one by one as soon as they're ready (and not in batch).
                // The benefits of having the first frames as quick as possible outweigh building up a buffer to cope with potential hiccups when the CPU suddenly gets busy.
                if (image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.cachedFrames[i] = image;
                        [self.cachedFrameIndexes addIndex:i];
                        [self.requestedFrameIndexes removeIndex:i];
#if DEBUG
                        if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImage:didUpdateCachedFrames:)]) {
                            [self.debug_delegate debug_animatedImage:self didUpdateCachedFrames:self.cachedFrameIndexes];
                        }
#endif
                    });
                }
            }
        };
        
        // Guard against crashing on 0-length ranges with an 'NSRangeException' "last range index (-1) beyond bounds" (Apple's error message is bogus here).
        // This is only needed on iOS 5, iPad only, running on device and only for the range {0,0} but regardless of whether the index set is mutable or immutable or what the indexes in the set are (can even be empty).
        if (firstRange.length > 0) {
            [frameIndexesToAddToCache enumerateRangesInRange:firstRange options:0 usingBlock:frameRangeBlock];
        }
        if (secondRange.length > 0) {
            [frameIndexesToAddToCache enumerateRangesInRange:secondRange options:0 usingBlock:frameRangeBlock];
        }
    });
}


+ (CGSize)sizeForImage:(id)image
{
    CGSize imageSize = CGSizeZero;
    
    // Early return for nil
    if (!image) {
        return imageSize;
    }
    
    if ([image isKindOfClass:[UIImage class]]) {
        UIImage *uiImage = (UIImage *)image;
        imageSize = uiImage.size;
    } else if ([image isKindOfClass:[FLAnimatedImage class]]) {
        FLAnimatedImage *animatedImage = (FLAnimatedImage *)image;
        imageSize = animatedImage.size;
    } else {
        // Bear trap to capture bad images; we have seen crashers cropping up on iOS 7.
        NSLog(@"Error: `image` isn't of expected types `UIImage` or `FLAnimatedImage`: %@", image);
    }
    
    return imageSize;
}


#pragma mark - Private Methods

#pragma mark Progressive Image Loading

-(void)appendDataForProgressiveLoad:(BOOL)final{
    
    // Early return if no data supplied!
    BOOL hasData = ([self.progressiveData length] > 0);
    if (!hasData) {
        NSLog(@"Error: No animated GIF data supplied.");
        return;
    }
    
    if (!_serialQueue) {
        _serialQueue = dispatch_queue_create("com.flipboard.framecachingqueue", DISPATCH_QUEUE_SERIAL);
    }
    /*
     image source must be updated with full data source . However, if we update iamgeSource as another thread is trying to add frames to cache, the app will crash because imageSource was changed unexpectantly. thus we should add the process of pdating the source to the same serial queue as is used by the caching blocks, so the caching block is never going run at the same time
     */
    dispatch_async(_serialQueue, ^{
        
        CGImageSourceUpdateData(_imageSource, (__bridge CFDataRef)[NSData dataWithData:self.progressiveData], final);
        
        //set readonly data finally
        if(final){
            _data = [NSData dataWithData:self.progressiveData];
            _progressiveData = nil;
        }
        
        // Early return if not GIF!
        CFStringRef imageSourceContainerType = CGImageSourceGetType(_imageSource);
        BOOL isGIFData = UTTypeConformsTo(imageSourceContainerType, kUTTypeGIF);
        if (!isGIFData) {
            NSLog(@"Error: Supplied data is of type %@ and doesn't seem to be GIF data %@", imageSourceContainerType, self.progressiveData );
            return;
        }
        
        [self processFrames];
        [self calculateCache];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(final){
                
                if([self.debug_delegate respondsToSelector:@selector(debug_didProgressivelyLoadFrames:)]) {
                    [self.debug_delegate debug_didProgressivelyLoadFrames:self];
                }
                if([self.debug_delegate respondsToSelector:@selector(debug_didCompleteProgressiveLoad:)]) {
                    [self.debug_delegate debug_didCompleteProgressiveLoad:self];
                }
                
            } else {
                
                if([self.debug_delegate respondsToSelector:@selector(debug_didProgressivelyLoadFrames:)]) {
                    [self.debug_delegate debug_didProgressivelyLoadFrames:self];
                }
            }
        });
    });
}

#pragma mark Frame Loading

- (UIImage *)predrawnImageAtIndex:(NSUInteger)index
{
    // It's very important to use the cached `_imageSource` since the random access to a frame with `CGImageSourceCreateImageAtIndex` turns from an O(1) into an O(n) operation when re-initializing the image source every time.
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(_imageSource, index, NULL);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CFRelease(imageRef);
    
    // Loading in the image object is only half the work, the displaying image view would still have to synchronosly wait and decode the image, so we go ahead and do that here on the background thread.
    image = [[self class] predrawnImageFromImage:image];
    
    return image;
}

-(void)processFrames{
    
    // Get `LoopCount`
    // Note: 0 means repeating the animation indefinitely.
    // Image properties example:
    // {
    //     FileSize = 314446;
    //     "{GIF}" = {
    //         HasGlobalColorMap = 1;
    //         LoopCount = 0;
    //     };
    // }
    NSDictionary *imageProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyProperties(_imageSource, NULL);
    _loopCount = [[[imageProperties objectForKey:(id)kCGImagePropertyGIFDictionary] objectForKey:(id)kCGImagePropertyGIFLoopCount] unsignedIntegerValue];
    
    // Iterate through frame images
    size_t imageCount = CGImageSourceGetCount(_imageSource);
    NSMutableArray *delayTimesMutable = [NSMutableArray arrayWithArray:_delayTimes];
    //start at the current frame count
    for (size_t i = _frameCount; i < imageCount; i++) {
        CGImageRef frameImageRef = CGImageSourceCreateImageAtIndex(_imageSource, i, NULL);
        if (frameImageRef) {
            UIImage *frameImage = [UIImage imageWithCGImage:frameImageRef];
            // Check for valid `frameImage` before parsing its properties as frames can be corrupted (and `frameImage` even `nil` when `frameImageRef` was valid).
            if (frameImage) {
                // Set poster image
                if (!self.posterImage) {
                    _posterImage = frameImage;
                    // Set its size to proxy our size.
                    _size = _posterImage.size;
                    // Remember index of poster image so we never purge it; also add it to the cache.
                    _posterImageFrameIndex = i;
                    self.cachedFrames[self.posterImageFrameIndex] = self.posterImage;
                    [self.cachedFrameIndexes addIndex:self.posterImageFrameIndex];
                } else {
                    // Placeholder indicates that we don't have a cached frame.
                    // We use an array instead of a dictionary for slightly faster access.
                    self.cachedFrames[i] = [NSNull null];
                }
                
                // Get `DelayTime`
                // Note: It's not in (1/100) of a second like still falsly described in the documentation as per iOS 7 but in seconds stored as `kCFNumberFloat32Type`.
                // Frame properties example:
                // {
                //     ColorModel = RGB;
                //     Depth = 8;
                //     PixelHeight = 960;
                //     PixelWidth = 640;
                //     "{GIF}" = {
                //         DelayTime = "0.4";
                //         UnclampedDelayTime = "0.4";
                //     };
                // }
                
                NSDictionary *frameProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(_imageSource, i, NULL);
                NSDictionary *framePropertiesGIF = [frameProperties objectForKey:(id)kCGImagePropertyGIFDictionary];
                
                // Try to use the unclamped delay time; fall back to the normal delay time.
                NSNumber *delayTime = [framePropertiesGIF objectForKey:(id)kCGImagePropertyGIFUnclampedDelayTime];
                if (!delayTime) {
                    delayTime = [framePropertiesGIF objectForKey:(id)kCGImagePropertyGIFDelayTime];
                }
                // If we don't get a delay time from the properties, fall back to `kDelayTimeIntervalDefault` or carry over the preceding frame's value.
                const NSTimeInterval kDelayTimeIntervalDefault = 0.1;
                if (!delayTime) {
                    if (i == 0) {
                        NSLog(@"Verbose: Falling back to default delay time for first frame %@ because none found in GIF properties %@", frameImage, frameProperties);
                        delayTime = @(kDelayTimeIntervalDefault);
                    } else {
                        NSLog(@"Verbose: Falling back to preceding delay time for frame %zu %@ because none found in GIF properties %@", i, frameImage, frameProperties);
                        delayTime = delayTimesMutable[i - 1];
                    }
                }
                // Support frame delays as low as `kDelayTimeIntervalMinimum`, with anything below being rounded up to `kDelayTimeIntervalDefault` for legacy compatibility.
                // This is how the fastest browsers do it as per 2012: http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser-compatibility
                const NSTimeInterval kDelayTimeIntervalMinimum = 0.02;
                // Use `[NSNumber compare:]` for comparison to let it decide how to deal with accurate float representation.
                if ([delayTime compare:@(kDelayTimeIntervalMinimum)] == NSOrderedAscending) {
                    NSLog(@"Verbose: Rounding frame %zu's `delayTime` from %f up to default %f (minimum supported: %f).", i, [delayTime floatValue], kDelayTimeIntervalDefault, kDelayTimeIntervalMinimum);
                    delayTime = @(kDelayTimeIntervalDefault);
                }
                delayTimesMutable[i] = delayTime;
            } else {
                NSLog(@"Verbose: Dropping frame %zu because valid `CGImageRef` %@ did result in `nil`-`UIImage`.", i, frameImageRef);
            }
            CFRelease(frameImageRef);
        } else {
            NSLog(@"Verbose: Dropping frame %zu because failed to `CGImageSourceCreateImageAtIndex` with image source %@", i, _imageSource);
        }
    }
    _delayTimes = [delayTimesMutable copy];
    _frameCount = [_delayTimes count];
}


#pragma mark Frame Caching

-(void)calculateCache{
    
    // Calculate the optimal frame cache size: try choosing a larger buffer window depending on the predicted image size.
    // It's only dependent on the image size & number of frames and never changes.
    CGFloat animatedImageDataSize = CGImageGetBytesPerRow(self.posterImage.CGImage) * self.size.height * self.frameCount / MEGABYTE;
    if (animatedImageDataSize <= FLAnimatedImageDataSizeCategoryAll) {
        _frameCacheSizeOptimal = self.frameCount;
    } else if (animatedImageDataSize <= FLAnimatedImageDataSizeCategoryDefault) {
        // This value doesn't depend on device memory much because if we're not keeping all frames in memory we will always be decoding 1 frame up ahead per 1 frame that gets played and at this point we might as well just keep a small buffer just large enough to keep from running out of frames.
        _frameCacheSizeOptimal = FLAnimatedImageFrameCacheSizeDefault;
    } else {
        // The predicted size exceeds the limits to build up a cache and we go into low memory mode from the beginning.
        _frameCacheSizeOptimal = FLAnimatedImageFrameCacheSizeLowMemory;
    }
    //in progressive loading we don't cache at all
    if(!_data){
        _frameCacheSizeOptimal = FLAnimatedImageFrameCacheSizeLowMemory;
    }
    
    // In any case, cap the optimal cache size at the frame count.
    _frameCacheSizeOptimal = MIN(_frameCacheSizeOptimal, self.frameCount);
    
    // Convenience/minor performance optimization; keep an index set handy with the full range to return in `-frameIndexesToCache`.
    _allFramesIndexSet = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, self.frameCount)];
    
}

- (NSIndexSet *)frameIndexesToCache
{
    NSIndexSet *indexesToCache = nil;
    // Quick check to avoid building the index set if the number of frames to cache equals the total frame count.
    if (self.frameCacheSizeCurrent == self.frameCount) {
        indexesToCache = self.allFramesIndexSet;
    } else {
        NSMutableIndexSet *indexesToCacheMutable = [[NSMutableIndexSet alloc] init];
        
        // Add indexes to the set in two separate blocks- the first starting from the requested frame index, up to the limit or the end.
        // The second, if needed, the remaining number of frames beginning at index zero.
        NSUInteger firstLength = MIN(self.frameCacheSizeCurrent, self.frameCount - self.requestedFrameIndex);
        NSRange firstRange = NSMakeRange(self.requestedFrameIndex, firstLength);
        [indexesToCacheMutable addIndexesInRange:firstRange];
        NSUInteger secondLength = self.frameCacheSizeCurrent - firstLength;
        if (secondLength > 0) {
            NSRange secondRange = NSMakeRange(0, secondLength);
            [indexesToCacheMutable addIndexesInRange:secondRange];
        }
        // Double check our math, before we add the poster image index which may increase it by one.
        if ([indexesToCacheMutable count] != self.frameCacheSizeCurrent) {
            NSLog(@"Error: Number of frames to cache doesn't equal expected cache size.");
        }
        
        [indexesToCacheMutable addIndex:self.posterImageFrameIndex];
        
        indexesToCache = [indexesToCacheMutable copy];
    }
    
    return indexesToCache;
}


- (void)purgeFrameCacheIfNeeded
{
    // Purge frames that are currently cached but don't need to be.
    // But not if we're still under the number of frames to cache.
    // This way, if all frames are allowed to be cached (the common case), we can skip all the `NSIndexSet` math below.
    if ([self.cachedFrameIndexes count] > self.frameCacheSizeCurrent) {
        NSMutableIndexSet *indexesToPurge = [self.cachedFrameIndexes mutableCopy];
        [indexesToPurge removeIndexes:[self frameIndexesToCache]];
        [indexesToPurge enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
            // Iterate through contiguous indexes; can be faster than `enumerateIndexesInRange:options:usingBlock:`.
            for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
                [self.cachedFrameIndexes removeIndex:i];
                self.cachedFrames[i] = [NSNull null];
                // Note: Don't `CGImageSourceRemoveCacheAtIndex` on the image source for frames that we don't want cached any longer to maintain O(1) time access.
#if DEBUG
                if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImage:didUpdateCachedFrames:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.debug_delegate debug_animatedImage:self didUpdateCachedFrames:self.cachedFrameIndexes];
                    });
                }
#endif
            }
        }];
    }
}


- (void)growFrameCacheSizeAfterMemoryWarning:(NSNumber *)frameCacheSize
{
    self.frameCacheSizeMaxInternal = [frameCacheSize unsignedIntegerValue];
    NSLog(@"Verbose: Grew frame cache size max to %lu after memory warning for animated image: %@", (unsigned long)self.frameCacheSizeMaxInternal, self);
    
    // Schedule resetting the frame cache size max completely after a while.
    const NSTimeInterval kResetDelay = 3.0;
    [self.weakProxy performSelector:@selector(resetFrameCacheSizeMaxInternal) withObject:nil afterDelay:kResetDelay];
}


- (void)resetFrameCacheSizeMaxInternal
{
    self.frameCacheSizeMaxInternal = FLAnimatedImageFrameCacheSizeNoLimit;
    NSLog(@"Verbose: Reset frame cache size max (current frame cache size: %lu) for animated image: %@", (unsigned long)self.frameCacheSizeCurrent, self);
}


#pragma mark System Memory Warnings Notification Handler

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    // Hold (and use!) a strong reference to self, since `NSNotificationCenter` no longer strongly references the observer.
    // This is another example of the lame fallout from the LLVM change in Xcode 5.1.
    FLAnimatedImage *strongSelf = self;
    
    strongSelf.memoryWarningCount++;
    
    // If we were about to grow larger, but got rapped on our knuckles by the system again, cancel.
    [NSObject cancelPreviousPerformRequestsWithTarget:strongSelf.weakProxy selector:@selector(growFrameCacheSizeAfterMemoryWarning:) object:@(FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning)];
    [NSObject cancelPreviousPerformRequestsWithTarget:strongSelf.weakProxy selector:@selector(resetFrameCacheSizeMaxInternal) object:nil];
    
    // Go down to the minimum and by that implicitly immediately purge from the cache if needed to not get jettisoned by the system and start producing frames on-demand.
    NSLog(@"Verbose: Attempt setting frame cache size max to %lu (previous was %lu) after memory warning #%lu for animated image: %@", (unsigned long)FLAnimatedImageFrameCacheSizeLowMemory, (unsigned long)strongSelf.frameCacheSizeMaxInternal, (unsigned long)strongSelf.memoryWarningCount, strongSelf);
    strongSelf.frameCacheSizeMaxInternal = FLAnimatedImageFrameCacheSizeLowMemory;
    
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
    if ((strongSelf.memoryWarningCount - 1) <= kGrowAttemptsMax) {
        [strongSelf.weakProxy performSelector:@selector(growFrameCacheSizeAfterMemoryWarning:) withObject:@(FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning) afterDelay:kGrowDelay];
    }
    
    // Note: It's not possible to get the level of a memory warning with a public API: http://stackoverflow.com/questions/2915247/iphone-os-memory-warnings-what-do-the-different-levels-mean/2915477#2915477
}


#pragma mark Image Decoding

// Decodes the image's data and draws it off-screen fully in memory; it's thread-safe and hence can be called on a background thread.
// On success, the returned object is a new `UIImage` instance with the same content as the one passed in.
// On failure, the returned object is the unchanged passed in one; the data will not be predrawn in memory though and an error will be logged.
// First inspired by & good Karma to: https://gist.github.com/steipete/1144242
+ (UIImage *)predrawnImageFromImage:(UIImage *)imageToPredraw
{
    // Always use a device RGB color space for simplicity and predictability what will be going on.
    CGColorSpaceRef colorSpaceDeviceRGBRef = CGColorSpaceCreateDeviceRGB();
    // Early return on failure!
    if (!colorSpaceDeviceRGBRef) {
        NSLog(@"Error: Failed to `CGColorSpaceCreateDeviceRGB` for image %@", imageToPredraw);
        return imageToPredraw;
    }
    
    // Even when the image doesn't have transparency, we have to add the extra channel because Quartz doesn't support other pixel formats than 32 bpp/8 bpc for RGB:
    // kCGImageAlphaNoneSkipFirst, kCGImageAlphaNoneSkipLast, kCGImageAlphaPremultipliedFirst, kCGImageAlphaPremultipliedLast
    // (source: docs "Quartz 2D Programming Guide > Graphics Contexts > Table 2-1 Pixel formats supported for bitmap graphics contexts")
    size_t numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpaceDeviceRGBRef) + 1; // 4: RGB + A
    
    // "In iOS 4.0 and later, and OS X v10.6 and later, you can pass NULL if you want Quartz to allocate memory for the bitmap." (source: docs)
    void *data = NULL;
    size_t width = imageToPredraw.size.width;
    size_t height = imageToPredraw.size.height;
    size_t bitsPerComponent = CHAR_BIT;
    
    size_t bitsPerPixel = (bitsPerComponent * numberOfComponents);
    size_t bytesPerPixel = (bitsPerPixel / BYTE_SIZE);
    size_t bytesPerRow = (bytesPerPixel * width);
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageToPredraw.CGImage);
    // If the alpha info doesn't match to one of the supported formats (see above), pick a reasonable supported one.
    // "For bitmaps created in iOS 3.2 and later, the drawing environment uses the premultiplied ARGB format to store the bitmap data." (source: docs)
    if (alphaInfo == kCGImageAlphaNone || alphaInfo == kCGImageAlphaOnly) {
        alphaInfo = kCGImageAlphaNoneSkipFirst;
    } else if (alphaInfo == kCGImageAlphaFirst) {
        alphaInfo = kCGImageAlphaPremultipliedFirst;
    } else if (alphaInfo == kCGImageAlphaLast) {
        alphaInfo = kCGImageAlphaPremultipliedLast;
    }
    // "The constants for specifying the alpha channel information are declared with the `CGImageAlphaInfo` type but can be passed to this parameter safely." (source: docs)
    bitmapInfo |= alphaInfo;
    
    // Create our own graphics context to draw to; `UIGraphicsGetCurrentContext`/`UIGraphicsBeginImageContextWithOptions` doesn't create a new context but returns the current one which isn't thread-safe (e.g. main thread could use it at the same time).
    // Note: It's not worth caching the bitmap context for multiple frames ("unique key" would be `width`, `height` and `hasAlpha`), it's ~50% slower. Time spent in libRIP's `CGSBlendBGRA8888toARGB8888` suddenly shoots up -- not sure why.
    CGContextRef bitmapContextRef = CGBitmapContextCreate(data, width, height, bitsPerComponent, bytesPerRow, colorSpaceDeviceRGBRef, bitmapInfo);
    CGColorSpaceRelease(colorSpaceDeviceRGBRef);
    // Early return on failure!
    if (!bitmapContextRef) {
        NSLog(@"Error: Failed to `CGBitmapContextCreate` with color space %@ and parameters (width: %zu height: %zu bitsPerComponent: %zu bytesPerRow: %zu) for image %@", colorSpaceDeviceRGBRef, width, height, bitsPerComponent, bytesPerRow, imageToPredraw);
        return imageToPredraw;
    }
    
    // Draw image in bitmap context and create image by preserving receiver's properties.
    CGContextDrawImage(bitmapContextRef, CGRectMake(0.0, 0.0, imageToPredraw.size.width, imageToPredraw.size.height), imageToPredraw.CGImage);
    CGImageRef predrawnImageRef = CGBitmapContextCreateImage(bitmapContextRef);
    UIImage *predrawnImage = [UIImage imageWithCGImage:predrawnImageRef scale:imageToPredraw.scale orientation:imageToPredraw.imageOrientation];
    CGImageRelease(predrawnImageRef);
    CGContextRelease(bitmapContextRef);
    
    // Early return on failure!
    if (!predrawnImage) {
        NSLog(@"Error: Failed to `imageWithCGImage:scale:orientation:` with image ref %@ created with color space %@ and bitmap context %@ and properties and properties (scale: %f orientation: %ld) for image %@", predrawnImageRef, colorSpaceDeviceRGBRef, bitmapContextRef, imageToPredraw.scale, (long)imageToPredraw.imageOrientation, imageToPredraw);
        return imageToPredraw;
    }
    
    return predrawnImage;
}

#pragma mark - NSURLSessionTaskDelegate

//request completes and we finish progressive load
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    
    //finalize image source
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        //append data to image source
        [self appendDataForProgressiveLoad:YES];
        
        if ([self.debug_delegate respondsToSelector:@selector(debug_didProgressivelyLoadFrames:)]) {
            [self.debug_delegate debug_didProgressivelyLoadFrames:self];
        }
    });
}

#pragma mark - NSURLSessionDataDelegate

//reequest recieves data and we determine whether to update the frames
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{
    
    static size_t lastFrameCount;
    static size_t lastLoad;

    [self.progressiveData appendData:data];
    
    //We need to create a source of our incremental data to see if there is additional frames to load  yet
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)_progressiveData, NULL);
    
    // get frame count
    size_t imageCount = CGImageSourceGetCount(imageSource);
    
    //if we have not made the poster image we need to do this ASAP
    if(!self.posterImage && imageCount > 1){
        
        NSLog(@"created poster image for frame count: %ld", imageCount);
        
        //create poster and possibly additional frames
        [self appendDataForProgressiveLoad:NO];
        lastLoad = imageCount;
        
        //otherwise wait for the frame period to load more images
    } else if(self.posterImage &&  imageCount > self.frameCount + self.progressiveLoadFramePeriod && lastLoad == self.frameCount){
        
        NSLog(@"appended data for frame count: %ld", imageCount);
    
        //append data to image source
        [self appendDataForProgressiveLoad:NO];
        lastLoad = imageCount;
    }
    lastFrameCount = imageCount;
}


#pragma mark - Description

- (NSString *)description
{
    NSString *description = [super description];
    
    description = [description stringByAppendingFormat:@" size=%@", NSStringFromCGSize(self.size)];
    description = [description stringByAppendingFormat:@" frameCount=%lu", (unsigned long)self.frameCount];
    
    return description;
}


@end


#pragma mark - FLWeakProxy

@interface FLWeakProxy ()

@property (nonatomic, weak) id target;

@end


@implementation FLWeakProxy

#pragma mark Life Cycle

+ (instancetype)weakProxyForObject:(id)targetObject
{
    FLWeakProxy *weakProxy = [FLWeakProxy alloc];
    weakProxy.target = targetObject;
    return weakProxy;
}


#pragma mark Forwarding Messages

- (id)forwardingTargetForSelector:(SEL)selector
{
    // Keep it lightweight: access the ivar directly
    return _target;
}


#pragma mark - NSWeakProxy Method Overrides
#pragma mark Handling Unimplemented Methods

- (void)forwardInvocation:(NSInvocation *)invocation
{
    // Fallback for when target is nil. Don't do anything, just return 0/NULL/nil.
    // The method signature we've received to get here is just a dummy to keep `doesNotRecognizeSelector:` from firing.
    // We can't really handle struct return types here because we don't know the length.
    void *nullPointer = NULL;
    [invocation setReturnValue:&nullPointer];
}


- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    // We only get here if `forwardingTargetForSelector:` returns nil.
    // In that case, our weak target has been reclaimed. Return a dummy method signature to keep `doesNotRecognizeSelector:` from firing.
    // We'll emulate the Obj-c messaging nil behavior by setting the return value to nil in `forwardInvocation:`, but we'll assume that the return value is `sizeof(void *)`.
    // Other libraries handle this situation by making use of a global method signature cache, but that seems heavier than necessary and has issues as well.
    // See https://www.mikeash.com/pyblog/friday-qa-2010-02-26-futures.html and https://github.com/steipete/PSTDelegateProxy/issues/1 for examples of using a method signature cache.
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

@end
