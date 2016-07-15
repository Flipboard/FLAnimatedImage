//
//  FLAnimatedGIFDataSource.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ImageIO/ImageIO.h>

#import "FLAnimatedImageFrameDataSource.h"

@interface FLAnimatedGIFDataSource : NSObject <FLAnimatedImageFrameDataSource>

- (instancetype)initWithImageSource:(CGImageSourceRef)imageSource;

@end

