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
#import "FLAnimatedImageDemo-Swift.h"

typedef NS_ENUM(NSUInteger, DebugViewStyle) {
    DebugViewStyleDefault,
    DebugViewStyleCondensed
};

@interface DebugView : UIView
<FLAnimatedImageDebugDelegate,
FLAnimatedImageViewDebugDelegate>

@property (nonatomic, weak) id<DebugAnimatedImage> image;
@property (nonatomic, weak) id imageView;
@property (nonatomic, assign) DebugViewStyle style;

@end
