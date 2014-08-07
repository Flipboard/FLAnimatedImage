//
//  RSPlayPauseButton.m
//
//  Created by Raphael Schaad https://github.com/raphaelschaad on 2014-03-22.
//  This is free and unencumbered software released into the public domain.
//


#import "RSPlayPauseButton.h"
#include <tgmath.h> // type generic math, yo: http://en.wikipedia.org/wiki/Tgmath.h#tgmath.h


static const CGFloat kScale = 1.0;
static const CGFloat kBorderSize = 32.0 * kScale;
static const CGFloat kBorderWidth = 3.0 * kScale;
static const CGFloat kSize = kBorderSize + kBorderWidth; // The total size is the border size + 2x half the border width.
static const CGFloat kPauseLineWidth = 4.0 * kScale;
static const CGFloat kPauseLineHeight = 15.0 * kScale;
static const CGFloat kPauseLinesSpace = 4.0 * kScale;
static const CGFloat kPlayTriangleOffsetX = 1.0 * kScale;
static const CGFloat kPlayTriangleTipOffsetX = 2.0 * kScale;

static const CGPoint p1 = {0.0, 0.0};                          // line 1, top left
static const CGPoint p2 = {kPauseLineWidth, 0.0};              // line 1, top right
static const CGPoint p3 = {kPauseLineWidth, kPauseLineHeight}; // line 1, bottom right
static const CGPoint p4 = {0.0, kPauseLineHeight};             // line 1, bottom left

static const CGPoint p5 = {kPauseLineWidth + kPauseLinesSpace, 0.0};                                // line 2, top left
static const CGPoint p6 = {kPauseLineWidth + kPauseLinesSpace + kPauseLineWidth, 0.0};              // line 2, top right
static const CGPoint p7 = {kPauseLineWidth + kPauseLinesSpace + kPauseLineWidth, kPauseLineHeight}; // line 2, bottom right
static const CGPoint p8 = {kPauseLineWidth + kPauseLinesSpace, kPauseLineHeight};                   // line 2, bottom left


@interface RSPlayPauseButton ()

@property (nonatomic, strong) CAShapeLayer *borderShapeLayer;
@property (nonatomic, strong) CAShapeLayer *playPauseShapeLayer;
@property (nonatomic, strong, readonly) UIBezierPath *pauseBezierPath;
@property (nonatomic, strong, readonly) UIBezierPath *pauseRotateBezierPath;
@property (nonatomic, strong, readonly) UIBezierPath *playBezierPath;
@property (nonatomic, strong, readonly) UIBezierPath *playRotateBezierPath;

@end


@implementation RSPlayPauseButton

#pragma mark - Accessors
#pragma mark Public

- (void)setPaused:(BOOL)paused
{
    if (_paused != paused) {
        [self setPaused:paused animated:NO];
    }
}

- (void)setColor:(UIColor *)color
{
    if (![_color isEqual:color]) {
        _color = color;
        
        [self setNeedsLayout];
    }
}


#pragma mark Private

@synthesize pauseBezierPath = _pauseBezierPath;

- (UIBezierPath *)pauseBezierPath
{
    if (!_pauseBezierPath) {
        _pauseBezierPath = [UIBezierPath bezierPath];
        
        // Subpath for 1. line
        [_pauseBezierPath moveToPoint:p1];
        [_pauseBezierPath addLineToPoint:p2];
        [_pauseBezierPath addLineToPoint:p3];
        [_pauseBezierPath addLineToPoint:p4];
        [_pauseBezierPath closePath];
        
        // Subpath for 2. line
        [_pauseBezierPath moveToPoint:p5];
        [_pauseBezierPath addLineToPoint:p6];
        [_pauseBezierPath addLineToPoint:p7];
        [_pauseBezierPath addLineToPoint:p8];
        [_pauseBezierPath closePath];
    }
    
    return _pauseBezierPath;
}


@synthesize pauseRotateBezierPath = _pauseRotateBezierPath;

- (UIBezierPath *)pauseRotateBezierPath
{
    if (!_pauseRotateBezierPath) {
        _pauseRotateBezierPath = [UIBezierPath bezierPath];
        
        // Subpath for 1. line
        [_pauseRotateBezierPath moveToPoint:p7];
        [_pauseRotateBezierPath addLineToPoint:p8];
        [_pauseRotateBezierPath addLineToPoint:p5];
        [_pauseRotateBezierPath addLineToPoint:p6];
        [_pauseRotateBezierPath closePath];
        
        // Subpath for 2. line
        [_pauseRotateBezierPath moveToPoint:p3];
        [_pauseRotateBezierPath addLineToPoint:p4];
        [_pauseRotateBezierPath addLineToPoint:p1];
        [_pauseRotateBezierPath addLineToPoint:p2];
        [_pauseRotateBezierPath closePath];
    }
    
    return _pauseRotateBezierPath;
}


@synthesize playBezierPath = _playBezierPath;

- (UIBezierPath *)playBezierPath
{
    if (!_playBezierPath) {
        _playBezierPath = [UIBezierPath bezierPath];
        
        const CGFloat kPauseLinesHalfSpace = floor(kPauseLinesSpace / 2);
        const CGFloat kPauseLineHalfHeight = floor(kPauseLineHeight / 2);
        
        CGPoint _p1 = CGPointMake(p1.x + kPlayTriangleOffsetX, p1.y);
        CGPoint _p2 = CGPointMake(p2.x + kPauseLinesHalfSpace, p2.y);
        CGPoint _p3 = CGPointMake(p3.x + kPauseLinesHalfSpace, p3.y);
        CGPoint _p4 = CGPointMake(p4.x + kPlayTriangleOffsetX, p4.y);
        
        CGPoint _p5 = CGPointMake(p5.x - kPauseLinesHalfSpace, p5.y);
        CGPoint _p6 = CGPointMake(p6.x + kPlayTriangleTipOffsetX, p6.y);
        CGPoint _p7 = CGPointMake(p7.x + kPlayTriangleTipOffsetX, p7.y);
        CGPoint _p8 = CGPointMake(p8.x - kPauseLinesHalfSpace, p8.y);
        
        const CGFloat kPlayTriangleWidth = _p6.x - _p1.x;
        
        _p2.y += kPauseLineHalfHeight * (_p2.x - kPlayTriangleOffsetX) / kPlayTriangleWidth;
        _p3.y -= kPauseLineHalfHeight * (_p3.x - kPlayTriangleOffsetX) / kPlayTriangleWidth;
        
        _p5.y += kPauseLineHalfHeight * (_p5.x - kPlayTriangleOffsetX) / kPlayTriangleWidth;
        
        _p6.y = kPauseLineHalfHeight;
        _p7.y = kPauseLineHalfHeight;
        
        _p8.y -= kPauseLineHalfHeight * (_p8.x - kPlayTriangleOffsetX) / kPlayTriangleWidth;
        
        [_playBezierPath moveToPoint:_p1];
        [_playBezierPath addLineToPoint:_p2];
        [_playBezierPath addLineToPoint:_p3];
        [_playBezierPath addLineToPoint:_p4];
        [_playBezierPath closePath];
        
        [_playBezierPath moveToPoint:_p5];
        [_playBezierPath addLineToPoint:_p6];
        [_playBezierPath addLineToPoint:_p7];
        [_playBezierPath addLineToPoint:_p8];
        [_playBezierPath closePath];
    }
    
    return _playBezierPath;
}


@synthesize playRotateBezierPath = _playRotateBezierPath;

- (UIBezierPath *)playRotateBezierPath
{
    if (!_playRotateBezierPath) {
        _playRotateBezierPath = [UIBezierPath bezierPath];
        
        const CGFloat kPauseLineHalfHeight = floor(kPauseLineHeight / 2);
        
        CGPoint _p1, _p2, _p3, _p4, _p5, _p6, _p7, _p8;
        _p1 = _p2 = _p5 = _p6 = CGPointMake(p6.x + kPlayTriangleTipOffsetX, kPauseLineHalfHeight);
        _p3 = _p8 = CGPointMake(p1.x + kPlayTriangleOffsetX, kPauseLineHalfHeight);
        _p4 = CGPointMake(p1.x + kPlayTriangleOffsetX, p1.y);
        _p7 = CGPointMake(p4.x + kPlayTriangleOffsetX, p4.y);
        
        [_playRotateBezierPath moveToPoint:_p1];
        [_playRotateBezierPath addLineToPoint:_p2];
        [_playRotateBezierPath addLineToPoint:_p3];
        [_playRotateBezierPath addLineToPoint:_p4];
        [_playRotateBezierPath closePath];
        
        [_playRotateBezierPath moveToPoint:_p5];
        [_playRotateBezierPath addLineToPoint:_p6];
        [_playRotateBezierPath addLineToPoint:_p7];
        [_playRotateBezierPath addLineToPoint:_p8];
        [_playRotateBezierPath closePath];
    }
    
    return _playRotateBezierPath;
}


#pragma mark - Life Cycle

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _paused = YES;
        _color = [UIColor colorWithWhite:0.04 alpha:1.0];
        _animationStyle = RSPlayPauseButtonAnimationStyleSplitAndRotate;
        
        [self sizeToFit];
    }
    return self;
}


#pragma mark - UIView Method Overrides
#pragma mark Configuring the Resizing Behavior

- (CGSize)sizeThatFits:(CGSize)size
{
    // Ignore the current size/new size by super, and instead use our default size.
    return CGSizeMake(kSize, kSize);
}


#pragma mark Laying out Subviews

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!self.borderShapeLayer) {
        self.borderShapeLayer = [[CAShapeLayer alloc] init];
        // Adjust for line width.
        CGRect borderRect = CGRectInset(self.bounds, ceil(kBorderWidth / 2), ceil(kBorderWidth / 2));
        self.borderShapeLayer.path = [UIBezierPath bezierPathWithOvalInRect:borderRect].CGPath;
        self.borderShapeLayer.lineWidth = kBorderWidth;
        self.borderShapeLayer.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:self.borderShapeLayer];
    }
    self.borderShapeLayer.strokeColor = self.color.CGColor;
    
    if (!self.playPauseShapeLayer) {
        self.playPauseShapeLayer = [[CAShapeLayer alloc] init];
        CGRect playPauseRect = CGRectZero;
        playPauseRect.origin.x = floor(((self.bounds.size.width) - (kPauseLineWidth + kPauseLinesSpace + kPauseLineWidth)) / 2);
        playPauseRect.origin.y = floor(((self.bounds.size.height) - (kPauseLineHeight)) / 2);
        playPauseRect.size.width = kPauseLineWidth + kPauseLinesSpace + kPauseLineWidth + kPlayTriangleTipOffsetX;
        playPauseRect.size.height = kPauseLineHeight;
        self.playPauseShapeLayer.frame = playPauseRect;
        UIBezierPath *path = self.isPaused ? self.playRotateBezierPath : self.pauseBezierPath;
        self.playPauseShapeLayer.path = path.CGPath;
        [self.layer addSublayer:self.playPauseShapeLayer];
    }
    self.playPauseShapeLayer.fillColor = self.color.CGColor;
}


#pragma mark - Public Methods

- (void)setPaused:(BOOL)paused animated:(BOOL)animated
{
    if (_paused != paused) {
        _paused = paused;
        
        UIBezierPath *fromPath = nil;
        UIBezierPath *toPath = nil;
        if (self.animationStyle == RSPlayPauseButtonAnimationStyleSplit) {
            fromPath = self.isPaused ? self.pauseBezierPath : self.playBezierPath;
            toPath = self.isPaused ? self.playBezierPath : self.pauseBezierPath;
        } else if (self.animationStyle == RSPlayPauseButtonAnimationStyleSplitAndRotate) {
            fromPath = self.isPaused ? self.pauseBezierPath : self.playRotateBezierPath;
            toPath = self.isPaused ? self.playRotateBezierPath : self.pauseRotateBezierPath;
        } else {
            // Unsupported animation style
        }
        
        if (animated) {
            // Morph between the two states.
            CABasicAnimation *morphAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            
            CAMediaTimingFunction *timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [morphAnimation setTimingFunction:timingFunction];
            
            // Make the new state stick.
            [morphAnimation setRemovedOnCompletion:NO];
            [morphAnimation setFillMode:kCAFillModeForwards];
            
            morphAnimation.duration = 0.3;
            morphAnimation.fromValue = (__bridge id)fromPath.CGPath;
            morphAnimation.toValue = (__bridge id)toPath.CGPath;
            
            [self.playPauseShapeLayer addAnimation:morphAnimation forKey:nil];
        } else {
            self.playPauseShapeLayer.path = toPath.CGPath;
        }
    }
}


@end
