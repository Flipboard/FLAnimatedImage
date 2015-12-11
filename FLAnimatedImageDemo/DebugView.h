//
//  DebugView.h
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//


#import <FLAnimatedImage/FLAnimatedImage.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, DebugViewStyle) {
    DebugViewStyleDefault,
    DebugViewStyleCondensed
};


// Conforms to private FLAnimatedImageDebugDelegate and FLAnimatedImageViewDebugDelegate protocols, used in sample project.
@interface DebugView : UIView

@property (nonatomic, weak) FLAnimatedImage *image;
@property (nonatomic, weak) FLAnimatedImageView *imageView;
@property (nonatomic, assign) DebugViewStyle style;

@end
