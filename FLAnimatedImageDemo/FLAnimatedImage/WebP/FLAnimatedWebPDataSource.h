//
//  FLAnimatedWebPDataSource.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FLAnimatedImageFrameDataSource.h"

#import <libwebp/demux.h>

@class FLAnimatedWebPDemuxer;

@interface FLAnimatedWebPDataSource : NSObject <FLAnimatedImageFrameDataSource>

/**
 * frameInfo - array of `FLAnimatedWebPFrameInfo` objects.
 */
- (instancetype)initWithWebPDemuxer:(FLAnimatedWebPDemuxer *)demuxer frameInfo:(NSArray *)frameInfo;

@end
