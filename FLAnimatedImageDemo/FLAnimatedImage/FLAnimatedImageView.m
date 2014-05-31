//
//  FLAnimatedImageView.h
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) 2013-2014 Flipboard. All rights reserved.
//


#import "FLAnimatedImageView.h"
#import "FLAnimatedImage.h"
#import <QuartzCore/QuartzCore.h>


@interface FLAnimatedImageView ()

// Override of public `readonly` properties as private `readwrite`
@property (nonatomic, strong, readwrite) UIImage *currentFrame;
@property (nonatomic, assign, readwrite) NSUInteger currentFrameIndex;

@property (nonatomic, assign) NSUInteger loopCountdown;
@property (nonatomic, assign) NSTimeInterval accumulator;
@property (nonatomic, strong, readonly) CADisplayLink *displayLink;

@property (nonatomic, assign) BOOL shouldAnimate; // Before checking this value, call `-updateShouldAnimate` whenever the animated image, window or superview has changed.
@property (nonatomic, assign) BOOL needsDisplayWhenImageBecomesAvailable;

@end


@implementation FLAnimatedImageView

#pragma mark - Accessors
#pragma mark Public

- (void)setAnimatedImage:(FLAnimatedImage *)animatedImage
{
    if (![_animatedImage isEqual:animatedImage]) {
        if (animatedImage) {
            // Clear out the image.
            super.image = nil;
        } else {
            // Stop animating before the animated image gets cleared out.
            [self stopAnimating];
        }
        
        _animatedImage = animatedImage;
        
        self.currentFrame = animatedImage.posterImage;
        self.currentFrameIndex = 0;
        if (animatedImage.loopCount > 0) {
            self.loopCountdown = animatedImage.loopCount;
        } else {
            self.loopCountdown = NSUIntegerMax;
        }
        self.accumulator = 0.0;
        
        // Start animating after the new animated image has been set.
        [self updateShouldAnimate];
        if (self.shouldAnimate) {
            [self startAnimating];
        }
        
        [self.layer setNeedsDisplay];
    }
}


#pragma mark Private

// Explicit synthesizing for `readonly` property with overridden getter.
@synthesize displayLink = _displayLink;

- (CADisplayLink *)displayLink
{
    if (!_displayLink) {
        // Create and setup display link lazily; add it immediately to the run loop but start out paused.
        // It is important to note the use of a weak proxy here to avoid a retain cycle. `-displayLinkWithTarget:selector:`
        // will retain its target until it is invalidated. We use a weak proxy so that the image view will get deallocated
        // independent of the display link's lifetime. Upon image view deallocation, we invalidate the display
        // link which will lead to the deallocation of both the display link and the weak proxy.
        FLWeakProxy *weakProxy = [FLWeakProxy weakProxyForObject:self];
        _displayLink = [CADisplayLink displayLinkWithTarget:weakProxy selector:@selector(displayDidRefresh:)];
        // `NSRunLoopCommonModes` would allow timer events during scrolling (i.e. animation) but we don't support this behavior.
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        _displayLink.paused = YES;
        
        // Note: The display link's `.frameInterval` value of 1 (default) means getting callbacks at the refresh rate of the display (~60Hz).
        // Setting it to 2 divides the frame rate by 2 and hence calls back at every other frame.
    }
    
    return _displayLink;
}


#pragma mark - Life Cycle

- (void)dealloc
{
    // Removes the display link from all run loop modes.
    // Don't call the getter here because it will unnecessarily create/attach a display link.
    [_displayLink invalidate];
}


#pragma mark - UIView Method Overrides
#pragma mark Observing View-Related Changes

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    
    [self updateShouldAnimate];
    if (self.shouldAnimate) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}


- (void)didMoveToWindow
{
    [super didMoveToWindow];
    
    [self updateShouldAnimate];
    if (self.shouldAnimate) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}


#pragma mark - UIImageView Method Overrides
#pragma mark Image Data

- (UIImage *)image
{
    UIImage *image = nil;
    if (self.animatedImage) {
        // Initially set to the poster image.
        image = self.currentFrame;
    } else {
        image = super.image;
    }
    return image;
}


- (void)setImage:(UIImage *)image
{
    if (image) {
        // Clear out the animated image and implicitly pause animation playback.
        self.animatedImage = nil;
    }
    
    super.image = image;
}


#pragma mark Animating Images

- (void)startAnimating
{
    if (self.animatedImage) {
        self.displayLink.paused = NO;
    } else {
        [super startAnimating];
    }
}


- (void)stopAnimating
{
    if (self.animatedImage) {
        self.displayLink.paused = YES;
    } else {
        [super stopAnimating];
    }
}


- (BOOL)isAnimating
{
    BOOL isAnimating = NO;
    if (self.animatedImage) {
        isAnimating = !self.displayLink.isPaused;
    } else {
        isAnimating = [super isAnimating];
    }
    return isAnimating;
}


#pragma mark - Private Methods
#pragma mark Animation

// Don't repeatedly check our window & superview in `-displayDidRefresh:` for performance reasons.
// Just update our cached value whenever the animated image, window or superview is changed.
- (void)updateShouldAnimate
{
    self.shouldAnimate = self.animatedImage && self.window && self.superview;
}


- (void)displayDidRefresh:(CADisplayLink *)displayLink
{
    // If for some reason a wild call makes it through when we shouldn't be animating, bail.
    // Early return!
    if (!self.shouldAnimate) {
        NSLog(@"Warn: Trying to animate image when we shouldn't: %@", self);
        return;
    }
    
    // If we have a nil image, don't update the view nor playhead.
    UIImage *image = [self.animatedImage imageLazilyCachedAtIndex:self.currentFrameIndex];
    if (image) {
        //NSLog(@"Verbose: Showing frame %d for animated image: %@", self.currentFrameIndex, self.animatedImage);
        self.currentFrame = image;
        if (self.needsDisplayWhenImageBecomesAvailable) {
            [self.layer setNeedsDisplay];
            self.needsDisplayWhenImageBecomesAvailable = NO;
        }
        
        self.accumulator += displayLink.duration;
        
        // While-loop first inspired by & good Karma to: https://github.com/ondalabs/OLImageView/blob/master/OLImageView.m
        while (self.accumulator >= [self.animatedImage.delayTimes[self.currentFrameIndex] floatValue]) {
            self.accumulator -= [self.animatedImage.delayTimes[self.currentFrameIndex] floatValue];
            self.currentFrameIndex++;
            if (self.currentFrameIndex >= self.animatedImage.frameCount) {
                // If we've looped the number of times that this animated image describes, stop looping.
                self.loopCountdown--;
                if (self.loopCountdown == 0) {
                    [self stopAnimating];
                    return;
                }
                self.currentFrameIndex = 0;
            }
            // Calling `-setNeedsDisplay` will just paint the current frame, not the new frame that we may have moved to.
            // Instead, set `needsDisplayWhenImageBecomesAvailable` to `YES` -- this will paint the new image once loaded.
            self.needsDisplayWhenImageBecomesAvailable = YES;
        }
    } else {
        //NSLog(@"Verbose: Waiting for frame %d for animated image: %@", self.currentFrameIndex, self.animatedImage);
#if DEBUG
        if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImageView:waitingForFrame:duration:)]) {
            [self.debug_delegate debug_animatedImageView:self waitingForFrame:self.currentFrameIndex duration:(NSTimeInterval)self.displayLink.duration];
        }
#endif
    }
}


#pragma mark - CALayerDelegate (Informal)
#pragma mark Providing the Layer's Content

- (void)displayLayer:(CALayer *)layer
{
    layer.contents = (__bridge id)self.currentFrame.CGImage;
}


@end
