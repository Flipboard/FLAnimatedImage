//
//  FLAnimatedImageData.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, FLAnimatedImageDataType) {
    FLAnimatedImageDataTypeGIF,
    FLAnimatedImageDataTypeWebP,
};

@interface FLAnimatedImageData : NSObject <NSCopying>

- (instancetype)initWithData:(NSData *)data type:(FLAnimatedImageDataType)type;

@property (nonatomic, readonly) FLAnimatedImageDataType type;
@property (nonatomic, readonly) NSData *data;

@end

