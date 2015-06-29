//
//  FLAnimatedImageData.m
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLAnimatedImageData.h"

@implementation FLAnimatedImageData

- (instancetype)initWithData:(NSData *)data type:(FLAnimatedImageDataType)type
{
    if (self = [super init]) {
        _data = data;
        _type = type;
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ data: %@; \n", [super description], _data];
}

- (NSUInteger)hash
{
    return _type ^ [_data hash];
}

- (BOOL)isEqual:(FLAnimatedImageData *)object
{
    if (object == nil || ![object isKindOfClass:[FLAnimatedImageData class]]) {
        return NO;
    }

    return _type == object->_type && (_data == object->_data ?: [_data isEqual:object->_data]);
}

@end

