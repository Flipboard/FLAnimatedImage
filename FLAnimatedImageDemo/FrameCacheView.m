//
//  FrameCacheView.m
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//


#import "FrameCacheView.h"
#import <FLAnimatedImage/FLAnimatedImage.h>


@implementation FrameCacheView

- (void)setImage:(FLAnimatedImage *)image
{
    if (![_image isEqual:image]) {
        _image = image;
        
        for (UIView *subview in self.subviews) {
            [subview removeFromSuperview];
        }
        
        for (NSUInteger i = 0; i < _image.frameCount; i++) {
            UIView *frameView = [[UIView alloc] init];
            frameView.layer.borderWidth = 1.0;
            frameView.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
            [self addSubview:frameView];
        }
        
        [self updateSubviewFrames];
        
        [self setNeedsLayout];
    }
}


- (void)setFrame:(CGRect)frame
{
    if (!CGRectEqualToRect(self.frame, frame)) {
        super.frame = frame;
        [self updateSubviewFrames];
        [self setNeedsLayout];
    }
}


- (void)setFramesInCache:(NSIndexSet *)framesInCache
{
    if (![_framesInCache isEqual:framesInCache]) {
        _framesInCache = framesInCache;
        [self setNeedsLayout];
    }
}


- (void)setRequestedFrameIndex:(NSUInteger)requestedFrameIndex
{
    if (_requestedFrameIndex != requestedFrameIndex) {
        _requestedFrameIndex = requestedFrameIndex;
        [self setNeedsLayout];
    }
}


- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.requestedFrameIndex = NSNotFound;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    NSUInteger i = 0;
    for (UIView *subview in self.subviews) {
        BOOL isRequestedFrame = (i == self.requestedFrameIndex);
        BOOL isCached = [self.framesInCache containsIndex:i];
        UIColor *fillColor = [UIColor clearColor];
        if (isCached) {
            fillColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        } else if (isRequestedFrame) {
            fillColor = [UIColor colorWithRed:0.8 green:0.15 blue:0.15 alpha:0.6];
        }
        subview.backgroundColor = fillColor;
        
        i++;
    }
}


- (void)updateSubviewFrames
{
    NSTimeInterval delayTimesTotal = [[[self.image.delayTimesForIndexes allValues] valueForKeyPath:@"@sum.self"] doubleValue];
    CGFloat x = 0.0;
    NSUInteger i = 0;
    for (UIView *subview in self.subviews) {
        CGFloat width = self.bounds.size.width * [self.image.delayTimesForIndexes[@(i)] doubleValue] / delayTimesTotal + subview.layer.borderWidth;
        CGRect frame = CGRectMake(x, 0.0, width, self.bounds.size.height);
        
        subview.frame = frame;
        
        x += width - subview.layer.borderWidth;
        i++;
    }
}


@end