//
//  FLAnimatedWebPDemuxer.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <libwebp/demux.h>

/**
 * FLAnimatedImage uses this class to create WebPDemuxer instances.
 * It handles ensuring that the lifetime of the underlying data for the WebPDemuxer
 * is at least as long as the WebPDemuxer instance.
 */
@interface FLAnimatedWebPDemuxer : NSObject

/**
 * We may fail to successfully create a WebPDemuxer with the given data,
 * so this class's initializer may return nil.
 */
- (instancetype)initWithData:(NSData *)data;

- (WebPDemuxer *)demuxer;

@end
