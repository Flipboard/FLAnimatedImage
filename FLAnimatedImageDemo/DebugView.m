//
//  DebugView.m
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//


#import "DebugView.h"
#import "GraphView.h"
#import "FrameCacheView.h"
#import "PlayheadView.h"
#import "RSPlayPauseButton.h"


@interface DebugView ()

@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) GraphView *memoryUsageView;
@property (nonatomic, strong) GraphView *frameDelayView;
@property (nonatomic, assign) NSTimeInterval currentFrameDelay;
@property (nonatomic, strong) RSPlayPauseButton *playPauseButton;
@property (nonatomic, strong) FrameCacheView *frameCacheView;
@property (nonatomic, strong) PlayheadView *playheadView;

@end


@implementation DebugView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.style = DebugViewStyleDefault;
    }
    return self;
}


- (void)setStyle:(DebugViewStyle)style
{
    if (_style != style) {
        _style = style;
        [self setNeedsLayout];
    }
}


- (CGFloat)frameCacheViewHeight
{
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? CGRectGetHeight(self.playPauseButton.frame) : 12.0;
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    const CGFloat kMargin = 10.0;
    
    if (!self.gradientLayer) {
        self.gradientLayer = [CAGradientLayer layer];
        self.gradientLayer.colors = @[(__bridge id)[UIColor colorWithWhite:0.0 alpha:0.85].CGColor, (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor, (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor, (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.85].CGColor];
        self.gradientLayer.locations = @[@0.0, @0.22, @0.78, @1.0];
        [self.layer addSublayer:self.gradientLayer];
    }
    self.gradientLayer.frame = self.bounds;
    
    if (!self.memoryUsageView) {
        self.memoryUsageView = [[GraphView alloc] init];
        [self addSubview:self.memoryUsageView];
    }
    self.memoryUsageView.numberOfDisplayedDataPoints = self.image.frameCount * 3;
    CGFloat memoryUsage = self.image.size.width * self.image.size.height * 4 * self.image.frameCount / 1024 / 1024;
    self.memoryUsageView.maxDataPoint = memoryUsage;
    self.memoryUsageView.shouldShowDescription = self.style == DebugViewStyleDefault;
    CGFloat memoryUsageViewWidth = 0.0;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        memoryUsageViewWidth = self.style == DebugViewStyleDefault ? 212.0 : 117.0;
    } else {
        memoryUsageViewWidth = CGRectGetWidth(self.bounds) - 2 * kMargin;
    }
    CGFloat memoryUsageViewHeight = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? 50.0 : 24.0;
    self.memoryUsageView.frame = CGRectMake(kMargin, kMargin, memoryUsageViewWidth, memoryUsageViewHeight);
    
    if (!self.frameDelayView) {
        self.frameDelayView = [[GraphView alloc] init];
        self.frameDelayView.style = GraphViewStyleFrameDelay;
        [self addSubview:self.frameDelayView];
    }
    self.frameDelayView.numberOfDisplayedDataPoints = self.image.frameCount * 3;
    self.frameDelayView.shouldShowDescription = self.style == DebugViewStyleDefault;
    CGFloat graphViewsSpacing = self.style == DebugViewStyleDefault ? 50.0 : 30.0;
    CGFloat frameDelayViewWidth = 0.0;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        frameDelayViewWidth = self.style == DebugViewStyleDefault ? 204.0 : 126.0;;
    } else {
        frameDelayViewWidth = CGRectGetWidth(self.bounds) - 2 * kMargin;
    }
    CGFloat frameDelayViewHeight = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? 50.0 : 24.0;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.frameDelayView.frame = CGRectMake(CGRectGetMaxX(self.memoryUsageView.frame) + graphViewsSpacing, kMargin, frameDelayViewWidth, frameDelayViewHeight);
    } else {
        self.frameDelayView.frame = CGRectMake(CGRectGetMinX(self.memoryUsageView.frame), CGRectGetMaxY(self.memoryUsageView.frame) + kMargin, frameDelayViewWidth, frameDelayViewHeight);
    }
    
    if (!self.playPauseButton) {
        self.playPauseButton = [[RSPlayPauseButton alloc] init];
        self.playPauseButton.paused = NO;
        CGRect frame = self.playPauseButton.frame;
        frame.origin = CGPointMake(CGRectGetMaxX(self.bounds) - frame.size.width - kMargin, CGRectGetMaxY(self.bounds) - frame.size.height - kMargin);
        self.playPauseButton.frame = frame;
        self.playPauseButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        self.playPauseButton.color = [UIColor colorWithWhite:0.8 alpha:1.0];
        [self.playPauseButton addTarget:self action:@selector(playPauseButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.playPauseButton];
    }
    
    if (!self.frameCacheView) {
        self.frameCacheView = [[FrameCacheView alloc] init];
        [self addSubview:self.frameCacheView];
    }
    self.frameCacheView.frame = CGRectMake(kMargin, CGRectGetHeight(self.bounds) - kMargin - [self frameCacheViewHeight], self.playPauseButton.frame.origin.x - 2 * kMargin, [self frameCacheViewHeight]);
    self.frameCacheView.image = self.image;
    
    if (!self.playheadView) {
        const CGFloat kSize = 10.0;
        self.playheadView = [[PlayheadView alloc] initWithFrame:CGRectMake(0.0, 0.0, kSize, kSize)];
        [self addSubview:self.playheadView];
    }
    self.playheadView.center = CGPointMake(self.frameCacheView.frame.origin.x, self.frameCacheView.frame.origin.y - floor(self.playheadView.bounds.size.height / 2) - 3.0);
}


#pragma mark - Play/Pause Action

- (void)playPauseButtonPressed:(RSPlayPauseButton *)playPauseButton
{
    if (self.playPauseButton.isPaused) {
        [self.playPauseButton setPaused:NO animated:YES];
        [self.imageView startAnimating];
    } else {
        [self.playPauseButton setPaused:YES animated:YES];
        [self.imageView stopAnimating];
    }
}


#pragma mark - FLAnimatedImageDebugDelegate

- (void)debug_animatedImage:(FLAnimatedImage *)animatedImage didUpdateCachedFrames:(NSIndexSet *)indexesOfFramesInCache
{
    self.frameCacheView.framesInCache = indexesOfFramesInCache;
}


- (void)debug_animatedImage:(FLAnimatedImage *)animatedImage didRequestCachedFrame:(NSUInteger)index
{
    if (self.frameCacheView.requestedFrameIndex != index) {
        self.frameCacheView.requestedFrameIndex = index;
        
        NSTimeInterval delayTime = [self.image.delayTimes[index] doubleValue];
        CGRect frameRect = ((UIView *)self.frameCacheView.subviews[index]).frame;
        
        CGPoint playheadStartCenter = CGPointMake(self.frameCacheView.frame.origin.x + frameRect.origin.x, self.playheadView.center.y);
        self.playheadView.center = playheadStartCenter;
        [UIView animateWithDuration:delayTime delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
            CGPoint playheadEndCenter = CGPointMake(playheadStartCenter.x + frameRect.size.width, playheadStartCenter.y);
            self.playheadView.center = playheadEndCenter;
        } completion:NULL];
        
        CGFloat memoryUsage = animatedImage.size.width * animatedImage.size.height * 4 * animatedImage.frameCacheSizeCurrent / 1024 / 1024;
        [self.memoryUsageView addDataPoint:memoryUsage];
        
        [self.frameDelayView addDataPoint:self.currentFrameDelay];
        self.currentFrameDelay = 0.0;
    }
}


#pragma mark - FLAnimatedImageViewDebugDelegate

- (void)debug_animatedImageView:(FLAnimatedImageView *)animatedImageView waitingForFrame:(NSUInteger)index duration:(NSTimeInterval)duration
{
    self.currentFrameDelay += duration;
}


@end
