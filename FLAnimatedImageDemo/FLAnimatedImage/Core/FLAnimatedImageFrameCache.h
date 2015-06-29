//
//  FLAnimatedImageFrameCache.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol FLAnimatedImageFrameDataSource;

#if defined(DEBUG) && DEBUG
@protocol FLAnimatedImageDebugDelegate;
#endif

@interface FLAnimatedImageFrameCache : NSObject

/**
 * FLAnimatedImageFrameCache is intended to be used by implementations of FLAnimatedImage. It tries to intelligently
 * choose the frame cache size depending on the image and memory situation with the goal to lower CPU usage for 
 * smaller ones, lower memory usage for larger ones and always deliver frames for high performant play-back.
 *
 * frameCount - number of frames in the image.
 * frameSize - size in bytes of each frame of the image.
 * posterImage - a static representation of the animated image, typically the first frame of the image.
 * posterImageIndex - the index of the poster image frame.
 */
- (instancetype)initWithFrameCount:(NSUInteger)frameCount
                 skippedFrameCount:(NSUInteger)skippedFrameCount
                         frameSize:(CGFloat)frameSize
                       posterImage:(UIImage *)posterImage
                  posterImageIndex:(NSUInteger)posterImageIndex
                        dataSource:(id<FLAnimatedImageFrameDataSource>)dataSource;

/**
 * This will return an image for the given index if it is already cached,
 * and if it it will begin preparing the image at this index and subsequent 
 * indexes to be cached.
 */
- (UIImage *)cachedImageAtIndex:(NSUInteger)index;

/**
 * Unlike cachedImageAtIndex, this is guaranteed to return an image.
 */
- (UIImage *)posterImage;

@property (nonatomic, assign, readonly) NSUInteger frameCacheSizeCurrent; // Current size of intelligently chosen buffer window; can range in the interval [1..frameCount]
@property (nonatomic, assign) NSUInteger frameCacheSizeMax; // Allow to cap the cache size; 0 means no specific limit (default)

#if defined(DEBUG) && DEBUG
// Only intended to report internal state for debugging
@property (nonatomic, weak) id<FLAnimatedImageDebugDelegate> debug_delegate;
#endif

@end
