//
//  FLAnimatedImage+WebP.m
//  Facebook
//
//  Created by Grant Paul.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "FLAnimatedImage+WebP.h"

#import <ImageIO/ImageIO.h>

#import <libwebp/demux.h>

#import "FLAnimatedImage+Internal.h"
#import "FLAnimatedGIFDataSource.h"
#import "FLAnimatedWebPDataSource.h"
#import "FLAnimatedWebPDemuxer.h"
#import "FLAnimatedWebPFrameInfo.h"
#import "FLWebPUtilities.h"

@implementation FLAnimatedImage (WebP)

+ (FLAnimatedImage *)animatedImageWithWebPData:(NSData *)data
{
    FLAnimatedWebPDemuxer *demuxer = [[FLAnimatedWebPDemuxer alloc] initWithData:data];
    if (!demuxer.demuxer) {
        return nil;
    }

    WebPIterator iterator;
    if (!WebPDemuxGetFrame(demuxer.demuxer, 1, &iterator)) {
        return nil;
    }

    int pixelHeight = WebPDemuxGetI(demuxer.demuxer, WEBP_FF_CANVAS_HEIGHT);
    int pixelWidth = WebPDemuxGetI(demuxer.demuxer, WEBP_FF_CANVAS_WIDTH);
    CGSize imageSize = CGSizeMake(pixelWidth, pixelHeight);
    CGRect imageRect = CGRectMake(0, 0, pixelWidth, pixelHeight);
    int loopCount = WebPDemuxGetI(demuxer.demuxer, WEBP_FF_LOOP_COUNT);
    int frameCount = iterator.num_frames;
    NSUInteger skippedFrameCount = 0;
    NSMutableDictionary *delayTimesForIndexesMutable = [NSMutableDictionary dictionaryWithCapacity:frameCount];
    NSMutableArray *frameInfosMutable = [NSMutableArray arrayWithCapacity:frameCount];

    UIImage *posterImage = nil;
    NSUInteger posterImageFrameIndex = 0;

    NSUInteger i = 0;
    do {
        CGRect frameRect = CGRectMake(iterator.x_offset, iterator.y_offset, iterator.width, iterator.height);
        // Ensure the frame rect doesn't exceed the image size. If it does, reduce the width/height appropriately
        if (CGRectGetMaxX(frameRect) > pixelWidth) {
            frameRect.size.width = pixelWidth - iterator.x_offset;
        }
        if (CGRectGetMaxY(frameRect) > pixelHeight) {
            frameRect.size.height = pixelHeight - iterator.y_offset;
        }
        BOOL disposeToBackground = (iterator.dispose_method == WEBP_MUX_DISPOSE_BACKGROUND);
        BOOL blendWithPreviousFrame = (iterator.blend_method == WEBP_MUX_BLEND);
        BOOL hasAlpha = iterator.has_alpha;
        FLAnimatedWebPFrameInfo *frameInfo =
        [[FLAnimatedWebPFrameInfo alloc] initWithFrameRect:frameRect
                                       disposeToBackground:disposeToBackground
                                    blendWithPreviousFrame:blendWithPreviousFrame
                                                  hasAlpha:hasAlpha];
        frameInfosMutable[i] = frameInfo;

        delayTimesForIndexesMutable[@(i)] = FLDelayTimeFloor(@((double)iterator.duration / 1000));

        if (posterImage == nil) {
            CGImageRef imageRef = FLWebPCreateCGImageWithBytes(iterator.fragment.bytes, iterator.fragment.size, frameRect, imageRect);
            if (imageRef) {
                posterImage = [UIImage imageWithCGImage:imageRef];
                posterImageFrameIndex = i;
                CGImageRelease(imageRef);
            } else {
                skippedFrameCount++;
            }
        }

        i++;
    } while (WebPDemuxNextFrame(&iterator));
    WebPDemuxReleaseIterator(&iterator);

    FLAnimatedWebPDataSource *dataSource = [[FLAnimatedWebPDataSource alloc] initWithWebPDemuxer:demuxer
                                                                                       frameInfo:frameInfosMutable];
    FLAnimatedImageData *webPData = [[FLAnimatedImageData alloc] initWithData:data type:FLAnimatedImageDataTypeWebP];

    return [[FLAnimatedImage alloc] initWithData:webPData
                                            size:imageSize
                                       loopCount:loopCount
                                      frameCount:frameCount
                               skippedFrameCount:skippedFrameCount
                            delayTimesForIndexes:delayTimesForIndexesMutable
                                     posterImage:posterImage
                                posterImageIndex:posterImageFrameIndex
                                 frameDataSource:dataSource];
}

@end
