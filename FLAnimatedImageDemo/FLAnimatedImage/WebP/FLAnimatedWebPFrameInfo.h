//
//  FLAnimatedWebPFrameInfo.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGBase.h>

@interface FLAnimatedWebPFrameInfo : NSObject <NSCopying>

/**
 * Each frame of an animated WebP may cover only a portion of the full image.
 * `frameRect` records what portion of the image this frame covers
 */
@property (nonatomic, readonly) CGRect frameRect;

/**
 * If YES, this frame will be replaced with blank space when the next frame
 * of the animation is rendered.
 */
@property (nonatomic, readonly) BOOL disposeToBackground;

/**
 * Whether transparent portions of this frame should be rendered on top of the
 * previous frame
 */
@property (nonatomic, readonly) BOOL blendWithPreviousFrame;

/**
 * Whether the frame has alpha.
 */
@property (nonatomic, readonly) BOOL hasAlpha;

/**
 * Designated initializer.
 */
- (instancetype)initWithFrameRect:(CGRect)frameRect disposeToBackground:(BOOL)disposeToBackground blendWithPreviousFrame:(BOOL)blendWithPreviousFrame hasAlpha:(BOOL)hasAlpha;

@end

