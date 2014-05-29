//
//  GraphView.m
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//


#import "GraphView.h"


@interface GraphView ()

@property (nonatomic, strong) NSMutableArray *dataPoints;
@property (nonatomic, strong) CAShapeLayer *graphLayer;
@property (nonatomic, strong) UILabel *topYAxisLabel;
@property (nonatomic, strong) UILabel *bottomYAxisLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;

@end


@implementation GraphView

- (void)setStyle:(GraphViewStyle)style
{
    if (_style != style) {
        _style = style;
        [self setNeedsLayout];
    }
}


- (void)setShouldShowDescription:(BOOL)shouldShowDescription
{
    if (_shouldShowDescription != shouldShowDescription) {
        _shouldShowDescription = shouldShowDescription;
        [self setNeedsLayout];
    }
}


- (CGFloat)maxDataPoint
{
    CGFloat maxDataPoint = _maxDataPoint;
    if (maxDataPoint <= 0.0) {
        maxDataPoint = [[self.dataPoints valueForKeyPath:@"@max.self"] doubleValue];;
    }
    return maxDataPoint;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.style = GraphViewStyleMemoryUsage;
        self.shouldShowDescription = YES;
        self.numberOfDisplayedDataPoints = 50;
        self.dataPoints = [NSMutableArray array];
        self.opaque = NO;
    }
    return self;
}


- (void)addDataPoint:(CGFloat)dataPoint
{
    if ([self.dataPoints count] >= self.numberOfDisplayedDataPoints) {
        [self.dataPoints removeObjectAtIndex:0];
    }
    [self.dataPoints addObject:@(dataPoint)];
    
    [self setNeedsLayout];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat rightEdge = CGRectGetMaxX(self.bounds);
    
    if (self.shouldShowDescription) {
        if (!self.descriptionLabel) {
            self.descriptionLabel = [[UILabel alloc] init];
            self.descriptionLabel.numberOfLines = 0;
            self.descriptionLabel.backgroundColor = [UIColor clearColor];
            self.descriptionLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
            self.descriptionLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:13.0];
            [self addSubview:self.descriptionLabel];
        }
        self.descriptionLabel.text = self.style == GraphViewStyleMemoryUsage ? @"Memory usage\n(in MB)" : @"Frame delay\n(in ms)";
        [self.descriptionLabel sizeToFit];
        self.descriptionLabel.frame = CGRectMake(rightEdge - self.descriptionLabel.bounds.size.width, self.bounds.origin.y, self.descriptionLabel.bounds.size.width, self.bounds.size.height);
        rightEdge = self.descriptionLabel.frame.origin.x - 8.0;
    }
    self.descriptionLabel.hidden = !self.shouldShowDescription;
    
    if (!self.bottomYAxisLabel) {
        self.bottomYAxisLabel = [[UILabel alloc] init];
        self.bottomYAxisLabel.backgroundColor = [UIColor clearColor];
        self.bottomYAxisLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
        self.bottomYAxisLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:13.0];
        self.bottomYAxisLabel.text = @"0";
        [self.bottomYAxisLabel sizeToFit];
        [self addSubview:self.bottomYAxisLabel];
    }
    self.bottomYAxisLabel.frame = CGRectMake(rightEdge - self.topYAxisLabel.bounds.size.width, CGRectGetMaxY(self.bounds) - floor(self.bottomYAxisLabel.bounds.size.height / 2), self.bottomYAxisLabel.bounds.size.width, self.bottomYAxisLabel.bounds.size.height);
    
    BOOL shouldShowTopYAxisLabel = self.maxDataPoint > 0.0;
    if (shouldShowTopYAxisLabel) {
        if (!self.topYAxisLabel) {
            self.topYAxisLabel = [[UILabel alloc] init];
            self.topYAxisLabel.backgroundColor = [UIColor clearColor];
            self.topYAxisLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
            self.topYAxisLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:13.0];
            [self addSubview:self.topYAxisLabel];
        }
        CGFloat topYAxisDataPoint = self.maxDataPoint;
        if (self.style == GraphViewStyleFrameDelay) {
            topYAxisDataPoint *= 1000;
        }
        topYAxisDataPoint *= 3.0 / 2.0;
        self.topYAxisLabel.text = [NSString stringWithFormat:@"%.1f", topYAxisDataPoint];
        [self.topYAxisLabel sizeToFit];
        self.topYAxisLabel.frame = CGRectMake(self.bottomYAxisLabel.frame.origin.x, self.bounds.origin.y - floor(self.topYAxisLabel.bounds.size.height / 2), self.topYAxisLabel.bounds.size.width, self.bottomYAxisLabel.bounds.size.height);
    }
    self.topYAxisLabel.hidden = !shouldShowTopYAxisLabel;
    
    if (!self.graphLayer) {
        self.graphLayer = [CAShapeLayer layer];
        self.graphLayer.masksToBounds = YES;
        self.graphLayer.borderWidth = 1.0;
        self.graphLayer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
        [self.layer addSublayer:self.graphLayer];
    }
    self.graphLayer.fillColor = self.style == GraphViewStyleMemoryUsage ? [UIColor colorWithWhite:1.0 alpha:0.5].CGColor : [UIColor colorWithRed:0.8 green:0.15 blue:0.15 alpha:0.6].CGColor;
    CGRect graphRect = UIEdgeInsetsInsetRect(self.bounds, UIEdgeInsetsMake(0.0, 0.0, 0.0, CGRectGetMaxX(self.bounds) - CGRectGetMinX(self.bottomYAxisLabel.frame) + 4.0));
    self.graphLayer.frame = graphRect;
    
    const CGFloat kGraphStepWidth = CGRectGetWidth(graphRect) / (self.numberOfDisplayedDataPoints - 1);
    CGFloat scaleFactor = 0.0;
    if (self.maxDataPoint > 0.0) {
        CGFloat maxHeightScaleFactor = self.style == GraphViewStyleMemoryUsage ? 0.9 : 0.7;
        scaleFactor = CGRectGetHeight(graphRect) * maxHeightScaleFactor / self.maxDataPoint;
    }
    CGFloat currentGraphX = CGRectGetMinX(graphRect);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(currentGraphX, CGRectGetMaxY(graphRect))];
    for (NSUInteger i = 0; i < self.numberOfDisplayedDataPoints; i++) {
        CGFloat graphHeight = 1.0;
        if (i < [self.dataPoints count]) {
            graphHeight += MAX(2.0, [self.dataPoints[i] doubleValue] * scaleFactor);
        }
        CGFloat graphY = CGRectGetMaxY(graphRect) - graphHeight;
        [path addLineToPoint:CGPointMake(currentGraphX, graphY)];
        currentGraphX += kGraphStepWidth;
    }
    [path addLineToPoint:CGPointMake(currentGraphX, CGRectGetHeight(graphRect))];
    [path closePath];
    
    self.graphLayer.path = path.CGPath;
}


@end
