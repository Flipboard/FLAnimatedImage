//
//  DebugAnimatedImage.h
//  FLAnimatedImageDemo
//
//  Created by David Kasper on 11/25/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DebugAnimatedImage <NSObject>
@property (nonatomic, readonly) NSArray *delayTimes;
@property (nonatomic, readonly) NSUInteger frameCount;
@property (nonatomic, readonly) CGSize size;
@end
