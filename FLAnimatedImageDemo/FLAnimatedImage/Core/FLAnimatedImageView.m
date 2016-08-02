//
//  FLAnimatedImageView.h
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) 2013-2015 Flipboard. All rights reserved.
//

#import "FLAnimatedImageView.h"

#import <QuartzCore/QuartzCore.h>

#import "FLAnimatedImage.h"
#import "FLWeakProxy.h"
#import "FLTimingUtilities.h"

static inline
NSTimeInterval DurationOfDisplayLink(CADisplayLink *displayLink)
{
	static BOOL greaterThanIOS9 = NO;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		greaterThanIOS9 = [[[UIDevice currentDevice] systemVersion] integerValue] > 9;
	});

	if (greaterThanIOS9) {
		return displayLink.duration;
	}
	return displayLink.duration * displayLink.frameInterval;
}

@interface FLAnimatedImageView ()

// Override of public `readonly` properties as private `readwrite`
@property (nonatomic, strong, readwrite) UIImage *currentFrame;
@property (nonatomic, assign, readwrite) NSUInteger currentFrameIndex;

@property (nonatomic, assign) NSUInteger loopCountdown;
@property (nonatomic, assign) NSTimeInterval accumulator;
@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, assign) BOOL shouldAnimate; // Before checking this value, call `-updateShouldAnimate` whenever the animated image, window or superview has changed.
@property (nonatomic, assign) BOOL needsDisplayWhenImageBecomesAvailable;
@property (nonatomic, assign) BOOL isUserPaused;

@end


@implementation FLAnimatedImageView

#pragma mark - Initializers

// -initWithImage: isn't documented as a designated initializer of UIImageView, but it actually seems to be.
// Using -initWithImage: doesn't call any of the other designated initializers.
- (instancetype)initWithImage:(UIImage *)image
{
	self = [super initWithImage:image];
	if (self) {
		[self commonInit];
	}
	return self;
}

// -initWithImage:highlightedImage: also isn't documented as a designated initializer of UIImageView, but it doesn't call any other designated initializers.
- (instancetype)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage
{
	self = [super initWithImage:image highlightedImage:highlightedImage];
	if (self) {
		[self commonInit];
	}
	return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self commonInit];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self commonInit];
	}
	return self;
}

- (void)commonInit
{
	self.runLoopMode = [[self class] defaultRunLoopMode];
}

#pragma mark - Accessors
#pragma mark Public

- (void)setAnimatedImage:(FLAnimatedImage *)animatedImage
{
    if (_animatedImage != animatedImage && ![_animatedImage isEqual:animatedImage]) {
        if (animatedImage) {
            // Clear out the image.
            super.image = nil;
            // Ensure disabled highlighting; it's not supported (see `-setHighlighted:`).
            super.highlighted = NO;
            // UIImageView seems to bypass some accessors when calculating its intrinsic content size, so this ensures its intrinsic content size comes from the animated image.
            [self invalidateIntrinsicContentSize];
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


#pragma mark - Life Cycle

- (void)dealloc
{
    // Removes the display link from all run loop modes.
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


#pragma mark Auto Layout

- (CGSize)intrinsicContentSize
{
    // Default to let UIImageView handle the sizing of its image, and anything else it might consider.
    CGSize intrinsicContentSize = [super intrinsicContentSize];
    
    // If we have have an animated image, use its image size.
    // UIImageView's intrinsic content size seems to be the size of its image. The obvious approach, simply calling `-invalidateIntrinsicContentSize` when setting an animated image, results in UIImageView steadfastly returning `{UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric}` for its intrinsicContentSize.
    // (Perhaps UIImageView bypasses its `-image` getter in its implementation of `-intrinsicContentSize`, as `-image` is not called after calling `-invalidateIntrinsicContentSize`.)
    if (self.animatedImage) {
        intrinsicContentSize = self.image.size;
    }
    
    return intrinsicContentSize;
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

- (void)play
{
    self.isUserPaused = NO;
    [self updateShouldAnimate];
    [self startAnimating];
}

- (void)pause
{
    self.isUserPaused = YES;
    [self updateShouldAnimate];
    [self stopAnimating];
}


- (void)startAnimating
{
    if (self.animatedImage) {
        // Lazily create the display link.
        if (!self.displayLink) {
            // It is important to note the use of a weak proxy here to avoid a retain cycle. `-displayLinkWithTarget:selector:`
            // will retain its target until it is invalidated. We use a weak proxy so that the image view will get deallocated
            // independent of the display link's lifetime. Upon image view deallocation, we invalidate the display
            // link which will lead to the deallocation of both the display link and the weak proxy.
            FLWeakProxy *weakProxy = [FLWeakProxy weakProxyForObject:self];
            self.displayLink = [CADisplayLink displayLinkWithTarget:weakProxy selector:@selector(displayDidRefresh:)];

			// Try to reduce refresh rate to keep lower cpu usage
			[self setupRefreshRateForDisplayLink:self.displayLink];

            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:self.runLoopMode];
        }
        self.displayLink.paused = NO;
    } else {
        [super startAnimating];
    }
}

- (void)setupRefreshRateForDisplayLink:(CADisplayLink *)displayLink
{

	NSArray *delayTimes = [self.animatedImage.delayTimesForIndexes allValues];
	CGFloat minDelay = [delayTimes.firstObject floatValue];

	for (NSNumber *delay in delayTimes) {
		CGFloat delayValue = [delay floatValue];
		if (delayValue < minDelay) {
			minDelay = delayValue;
		}
	}

	if (minDelay < kDelayTimeIntervalMinimum) {
		minDelay = kDelayTimeIntervalDefault;
	}

	NSInteger maximumFramesPerSecond = ceil(1.0 / minDelay);
	
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
	if ([displayLink respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
		FLLogDebug(@"Update display link refresh rate using setPreferredFramesPerSecond: %ld", (long)maximumFramesPerSecond);
		[displayLink setPreferredFramesPerSecond:maximumFramesPerSecond];
	}
	else {
#endif
		NSInteger interval = 59 / maximumFramesPerSecond + 1;
		FLLogDebug(@"Update display link refresh rate using setFrameInterval: %ld", (long)interval);
		displayLink.frameInterval = interval;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
	}
#endif
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
        isAnimating = self.displayLink && !self.displayLink.isPaused;
    } else {
        isAnimating = [super isAnimating];
    }
    return isAnimating;
}

#pragma mark Highlighted Image Unsupport

- (void)setHighlighted:(BOOL)highlighted
{
    // -[UIImageView setHighlighted] messes with the image being displayed, causing this to become blank if it
    // was playing an animated image. For now just don't react to setHighlighted being called, this could be modified
    // in the future if the concept of a 'highlighted animated image' is needed.
    // Highlighted image is unsupported for animated images, but implementing it breaks the image view when embedded in a UICollectionViewCell.
    if (self.animatedImage) {
        [super setHighlighted:highlighted];
    }
}


#pragma mark - Private Methods
#pragma mark Animation

// Don't repeatedly check our window & superview in `-displayDidRefresh:` for performance reasons.
// Just update our cached value whenever the animated image, window or superview is changed.
- (void)updateShouldAnimate
{
    self.shouldAnimate = self.animatedImage && self.window && self.superview && !self.isUserPaused;
    // CADisplayLink changes from paused == YES to paused == NO when we navigate away from this view and back
    // This is a hack to ensure that we restore the state to what it was supposed to be
    if (self.animatedImage && self.isUserPaused) {
        self.displayLink.paused = YES;
    }
}


- (void)displayDidRefresh:(CADisplayLink *)displayLink
{
	// If for some reason a wild call makes it through when we shouldn't be animating, bail.
	// Early return!
	if (!self.shouldAnimate) {
		FLLogWarn(@"Trying to animate image when we shouldn't: %@", self);
		return;
	}

	self.accumulator += DurationOfDisplayLink(displayLink);
	BOOL needRedo = NO;

	// While-loop first inspired by & good Karma to: https://github.com/ondalabs/OLImageView/blob/master/OLImageView.m
	do {
		needRedo = NO;
		NSNumber *delayTimeNumber = [self.animatedImage.delayTimesForIndexes objectForKey:@(self.currentFrameIndex)];
		NSTimeInterval delayTime = kDelayTimeIntervalDefault;

		if (delayTimeNumber) {
			delayTime = [delayTimeNumber floatValue];
		}

		// Image is lazily loaded, we need trigle generate image action as early as possible
		UIImage *image = [self.animatedImage imageLazilyCachedAtIndex:self.currentFrameIndex];

		if (self.accumulator >= delayTime) {
			self.accumulator -= delayTime;
			self.currentFrameIndex++;
			needRedo = YES; // Check if needs handle next frame in the same refresh duration

			if (self.currentFrameIndex >= self.animatedImage.frameCount) {
				// If we've looped the number of times that this animated image describes, stop looping.
				self.loopCountdown--;
				if (self.loopCompletionBlock) {
					self.loopCompletionBlock(self.loopCountdown);
				}

				if (self.loopCountdown == 0) {
					[self stopAnimating];
					needRedo = NO; // We should stop animation, but still need to show the current frame
				}
				self.currentFrameIndex = 0; // reset frame index for next loop
			}

			if (image) {
				self.currentFrame = image;
				[self.layer setNeedsDisplay];
			}
#if defined(DEBUG) && DEBUG
			else {
				FLLogDebug(@"Waiting for frame %lu for animated image: %@", (unsigned long)self.currentFrameIndex, self.animatedImage);

				if ([self.debug_delegate respondsToSelector:@selector(debug_animatedImageView:waitingForFrame:duration:)]) {
					[self.debug_delegate debug_animatedImageView:self waitingForFrame:self.currentFrameIndex duration:(NSTimeInterval)self.displayLink.duration];
				}
			}
#endif
		}
	} while(needRedo);
}

+ (NSString *)defaultRunLoopMode
{
	// Key off `activeProcessorCount` (as opposed to `processorCount`) since the system could shut down cores in certain situations.
	return [NSProcessInfo processInfo].activeProcessorCount > 1 ? NSRunLoopCommonModes : NSDefaultRunLoopMode;
}


#pragma mark - CALayerDelegate (Informal)
#pragma mark Providing the Layer's Content

- (void)displayLayer:(CALayer *)layer
{
    layer.contents = (__bridge id)self.image.CGImage;
}


@end
