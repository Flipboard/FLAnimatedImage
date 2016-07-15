//
//  FLAnimatedImage+Internal.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLAnimatedImage.h"

@interface FLAnimatedImage (Internal)

- (instancetype)initWithData:(FLAnimatedImageData *)data
                        size:(CGSize)size
                   loopCount:(NSUInteger)loopCount
                  frameCount:(NSUInteger)frameCount
           skippedFrameCount:(NSUInteger)skippedFrameCount
        delayTimesForIndexes:(NSDictionary *)delayTimesForIndexes
                 posterImage:(UIImage *)posterImage
            posterImageIndex:(NSUInteger)posterImageIndex
             frameDataSource:(id<FLAnimatedImageFrameDataSource>)frameDataSource;

@end


