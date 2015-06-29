//
//  FLAnimatedImageFrameDataSource.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol FLAnimatedImageFrameDataSource <NSObject>

/**
 * Return a pre-drawn image at the given index.
 *
 * This may be called off the main thread.
 */
- (UIImage *)imageAtIndex:(NSUInteger)index;

- (BOOL)frameRequiresBlendingWithPreviousFrame:(NSUInteger)index;

- (UIImage *)blendImage:(UIImage *)image atIndex:(NSUInteger)index withPreviousImage:(UIImage *)previousImage;

@end
