//
//  FrameCacheView.h
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//


#import <UIKit/UIKit.h>

@class FLAnimatedImage;


@interface FrameCacheView : UIView

@property (nonatomic, strong) FLAnimatedImage *image;
@property (nonatomic, strong) NSIndexSet *framesInCache;
@property (nonatomic, assign) NSUInteger requestedFrameIndex;

@end
