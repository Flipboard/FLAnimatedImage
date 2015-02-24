//
//  DebugView.h
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//


#import "FLAnimatedImage.h"
#import "FLAnimatedImageView.h"
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, DebugViewStyle) {
    DebugViewStyleDefault,
    DebugViewStyleCondensed
};


@interface DebugView : UIView
#if defined(DEBUG) && DEBUG
<FLAnimatedImageDebugDelegate,
FLAnimatedImageViewDebugDelegate>
#endif

@property (nonatomic, weak) FLAnimatedImage *image;
@property (nonatomic, weak) FLAnimatedImageView *imageView;
@property (nonatomic, assign) DebugViewStyle style;

@end
