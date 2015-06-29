//
//  FLAnimatedWebPDemuxer.m
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLAnimatedWebPDemuxer.h"

#import <libwebp/decode.h>

@implementation FLAnimatedWebPDemuxer
{
    WebPDemuxer *_demuxer;
    NSData *_data;
}

- (instancetype)initWithData:(NSData *)data
{
    if (self = [super init]) {
        _data = [data copy];

        WebPData webpdata;
        webpdata.bytes = [_data bytes];
        webpdata.size = [_data length];
        WebPDemuxer *demuxer = WebPDemux(&webpdata);
        if (!demuxer) {
            return nil;
        }

        _demuxer = demuxer;
    }
    return self;
}

- (void)dealloc
{
    WebPDemuxDelete(_demuxer);
}

- (WebPDemuxer *)demuxer
{
    return _demuxer;
}

@end
