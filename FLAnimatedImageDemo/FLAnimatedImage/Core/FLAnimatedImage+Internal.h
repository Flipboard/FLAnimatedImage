//
//  FLAnimatedImage+Internal.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLAnimatedImage.h"

@interface FLAnimatedImage (Internal)

- (instancetype)initWithData:(FLAnimatedImageData *)data
                        size:(CGSize)size
                   loopCount:(NSUInteger)loopCount
                  frameCount:(NSUInteger)frameCount
           skippedFrameCount:(NSUInteger)skippedFrameCount
        delayTimesForIndexes:(NSDictionary *)delayTimesForIndexes
                 posterImage:(UIImage *)posterImage
            posterImageIndex:(NSUInteger)posterImageIndex
             frameDataSource:(id<FLAnimatedImageFrameDataSource>)frameDataSource;

@end

// If a frame has a delay time less than kDelayTimeIntervalMinimum, we instead use kDelayTimeIntervalDefault as the
// delay time, as it is assumed that that delay time is unintentional. This is consistent with how browsers behave.
// See the comments on FLDelayTimeFloor for more details.
static const NSTimeInterval kDelayTimeIntervalMinimum = 0.02;
static const NSTimeInterval kDelayTimeIntervalDefault = 0.1;

static NSNumber *FLDelayTimeFloor(NSNumber *delayTime)
{
    // Support frame delays as low as `kDelayTimeIntervalMinimum`, with anything below being rounded up to `kDelayTimeIntervalDefault` for legacy compatibility.
    // This is how the fastest browsers do it as per 2012: http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser-compatibility
    // To support the minimum even when rounding errors occur, use an epsilon when comparing. We downcast to float because that's what we get for delayTime from ImageIO.
    if ([delayTime floatValue] < ((float)kDelayTimeIntervalMinimum - FLT_EPSILON)) {
        FLLogInfo(@"Rounding frame %zu's `delayTime` from %f up to default %f (minimum supported: %f).", i, [delayTime floatValue], kDelayTimeIntervalDefault, kDelayTimeIntervalMinimum);
        return @(kDelayTimeIntervalDefault);
    }
    return delayTime;
}
