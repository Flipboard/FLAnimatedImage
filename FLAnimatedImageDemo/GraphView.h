//
//  GraphView.h
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//


#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, GraphViewStyle) {
    GraphViewStyleMemoryUsage,
    GraphViewStyleFrameDelay
};


@interface GraphView : UIView

@property (nonatomic, assign) GraphViewStyle style; // Default is `GraphViewStyleMemoryUsage`
@property (nonatomic, assign) BOOL shouldShowDescription; // Default is YES
@property (nonatomic, assign) NSUInteger numberOfDisplayedDataPoints; // Default is 50
@property (nonatomic, assign) CGFloat maxDataPoint; // Default is the max of all data points added so far

- (void)addDataPoint:(CGFloat)dataPoint;

@end
