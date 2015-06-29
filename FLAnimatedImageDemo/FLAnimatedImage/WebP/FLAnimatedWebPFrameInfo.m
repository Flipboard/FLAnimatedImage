//
//  FLAnimatedWebPFrameInfo.m
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLAnimatedWebPFrameInfo.h"

@implementation FLAnimatedWebPFrameInfo

- (instancetype)initWithFrameRect:(CGRect)frameRect disposeToBackground:(BOOL)disposeToBackground blendWithPreviousFrame:(BOOL)blendWithPreviousFrame hasAlpha:(BOOL)hasAlpha
{
    if (self = [super init]) {
        _frameRect = frameRect;
        _disposeToBackground = disposeToBackground;
        _blendWithPreviousFrame = blendWithPreviousFrame;
        _hasAlpha = hasAlpha;
    }

    return self;
}

@synthesize frameRect = _frameRect;

@synthesize disposeToBackground = _disposeToBackground;

@synthesize blendWithPreviousFrame = _blendWithPreviousFrame;

@synthesize hasAlpha = _hasAlpha;


#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // Immutable.
    return self;
}

@end
