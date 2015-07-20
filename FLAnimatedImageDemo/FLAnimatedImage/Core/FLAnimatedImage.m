//
//  FLAnimatedImage.m
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) 2013-2015 Flipboard. All rights reserved.
//

#import "FLAnimatedImage.h"
#import "FLAnimatedImage+Internal.h"
#import "FLAnimatedImageFrameCache.h"

#define MEGABYTE (1024 * 1024)

#if FLLumberjackIntegrationEnabled && defined(FLLumberjackAvailable)
    #if defined(DEBUG) && DEBUG
        #if defined(LOG_LEVEL_DEBUG) // CocoaLumberjack 1.x
            int flAnimatedImageLogLevel = LOG_LEVEL_DEBUG;
        #else // CocoaLumberjack 2.x
            int flAnimatedImageLogLevel = DDLogFlagDebug;
        #endif
    #else
        #if defined(LOG_LEVEL_WARN) // CocoaLumberjack 1.x
            int flAnimatedImageLogLevel = LOG_LEVEL_WARN;
        #else // CocoaLumberjack 2.x
            int flAnimatedImageLogLevel = DDLogFlagWarning;
        #endif
    #endif
#endif

#if defined(DEBUG) && DEBUG
@interface FLAnimatedImage () <FLAnimatedImageDebugDelegate>
@end
#endif

@implementation FLAnimatedImage
{
    FLAnimatedImageFrameCache *_frameCache;
}

#pragma mark - Accessors
#pragma mark Public

- (NSUInteger)frameCacheSizeCurrent
{
    return _frameCache.frameCacheSizeCurrent;
}


- (void)setFrameCacheSizeMax:(NSUInteger)frameCacheSizeMax
{
    _frameCache.frameCacheSizeMax = frameCacheSizeMax;
}


#pragma mark - Life Cycle

- (instancetype)initWithData:(FLAnimatedImageData *)data
                        size:(CGSize)size
                   loopCount:(NSUInteger)loopCount
                  frameCount:(NSUInteger)frameCount
           skippedFrameCount:(NSUInteger)skippedFrameCount
        delayTimesForIndexes:(NSDictionary *)delayTimesForIndexes
                 posterImage:(UIImage *)posterImage
            posterImageIndex:(NSUInteger)posterImageIndex
             frameDataSource:(id<FLAnimatedImageFrameDataSource>)frameDataSource
{
    if (self = [super init]) {
        _frameDataSource = frameDataSource;
        _frameCache = [[FLAnimatedImageFrameCache alloc] initWithFrameCount:frameCount
                                                          skippedFrameCount:skippedFrameCount
                                                                  frameSize:CGImageGetBytesPerRow(posterImage.CGImage) * size.height
                                                                posterImage:posterImage
                                                           posterImageIndex:posterImageIndex
                                                                 dataSource:frameDataSource];
#if defined(DEBUG) && DEBUG
        _frameCache.debug_delegate = self;
#endif
        _frameCount = frameCount;
        _size = size;
        _loopCount = loopCount;
        _delayTimesForIndexes = [delayTimesForIndexes copy];
        _data = data;
    }
    return self;
}

- (id)init
{
    return nil;
}


#pragma mark - Public Methods

- (UIImage *)posterImage
{
    return [_frameCache posterImage];
}

// See header for more details.
// Note: both consumer and producer are throttled: consumer by frame timings and producer by the available memory (max buffer window size).
- (UIImage *)imageLazilyCachedAtIndex:(NSUInteger)index
{
    return [_frameCache cachedImageAtIndex:index];
}

#pragma mark - Description

- (NSString *)description
{
    NSString *description = [super description];

    description = [description stringByAppendingFormat:@" size=%@", NSStringFromCGSize(self.size)];
    description = [description stringByAppendingFormat:@" frameCount=%lu", (unsigned long)self.frameCount];

    return description;
}

#pragma mark - Debugging

#if defined(DEBUG) && DEBUG

- (void)debug_animatedImage:(FLAnimatedImage *)animatedImage didUpdateCachedFrames:(NSIndexSet *)indexesOfFramesInCache
{
    [self.debug_delegate debug_animatedImage:self didUpdateCachedFrames:indexesOfFramesInCache];
}

- (void)debug_animatedImage:(FLAnimatedImage *)animatedImage didRequestCachedFrame:(NSUInteger)index
{
    [self.debug_delegate debug_animatedImage:animatedImage didRequestCachedFrame:index];
}

- (CGFloat)debug_animatedImagePredrawingSlowdownFactor:(FLAnimatedImage *)animatedImage
{
    return [self.debug_delegate debug_animatedImagePredrawingSlowdownFactor:self];
}

#endif

@end
