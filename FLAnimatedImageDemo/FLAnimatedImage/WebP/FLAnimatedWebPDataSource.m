//
//  FLAnimatedWebPDataSource.m
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLAnimatedWebPDataSource.h"

#import <libwebp/decode.h>

#import "FLAnimatedWebPDemuxer.h"
#import "FLAnimatedWebPFrameInfo.h"
#import "FLWebPUtilities.h"

@implementation FLAnimatedWebPDataSource
{
    FLAnimatedWebPDemuxer *_demuxer;
    NSArray *_frameInfo;
    NSData *_data;

    CGRect _imageRect;
}

- (instancetype)initWithWebPDemuxer:(FLAnimatedWebPDemuxer *)demuxer frameInfo:(NSArray *)frameInfo
{
    self = [super init];
    if (self) {
        _demuxer = demuxer;
        _frameInfo = [frameInfo copy];

        int pixelHeight = WebPDemuxGetI(_demuxer.demuxer, WEBP_FF_CANVAS_HEIGHT);
        int pixelWidth = WebPDemuxGetI(_demuxer.demuxer, WEBP_FF_CANVAS_WIDTH);
        _imageRect = CGRectMake(0, 0, pixelWidth, pixelHeight);
    }
    return self;
}

- (UIImage *)imageAtIndex:(NSUInteger)index
{
    WebPIterator iterator;
    if (!WebPDemuxGetFrame(_demuxer.demuxer, (int)index + 1, &iterator)) {
        return nil;
    }

    CGImageRef imageRef = FLWebPCreateCGImageWithBytes(iterator.fragment.bytes, iterator.fragment.size, [_frameInfo[index] frameRect], _imageRect);
    UIImage *image = nil;
    if (imageRef) {
        image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
    }

    WebPDemuxReleaseIterator(&iterator);

    return image;
}

- (BOOL)frameRequiresBlendingWithPreviousFrame:(NSUInteger)index
{
    if (index == 0) {
        return NO;
    }

    FLAnimatedWebPFrameInfo *frameInfo = _frameInfo[index];
    BOOL frameCoversImage = CGRectContainsRect(frameInfo.frameRect, _imageRect);
    // If this frame covers the full image, and doesn't require blending, or doesn't have any alpha,
    // it does not require blending with the previous frame.
    if (frameCoversImage && (!frameInfo.blendWithPreviousFrame || !frameInfo.hasAlpha)) {
        return NO;
    }

    NSUInteger previousIndex = index - 1;
    FLAnimatedWebPFrameInfo *previousFrameInfo = _frameInfo[previousIndex];
    if (previousFrameInfo.disposeToBackground) {
        // If the previous frame covers the full image, and will be cleared, we don't need to blend
        if (CGRectContainsRect(previousFrameInfo.frameRect, _imageRect)) {
            return NO;
        }
        // If the previous frame will be cleared, and it doesn't require blending with previous frames, we don't need to blend
        if ([self frameRequiresBlendingWithPreviousFrame:previousIndex] == NO) {
            return NO;
        }
        return YES;
    } else {
        return YES;
    }
}

- (UIImage *)blendImage:(UIImage *)image atIndex:(NSUInteger)index withPreviousImage:(UIImage *)previousImage
{
    FLAnimatedWebPFrameInfo *previousFrameInfo = _frameInfo[index - 1];
    FLAnimatedWebPFrameInfo *frameInfo = _frameInfo[index];

    UIGraphicsBeginImageContext(_imageRect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    [previousImage drawAtPoint:CGPointZero];
    if (previousFrameInfo.disposeToBackground) {
        // Erase part of the previous image covered by the previous frame if it specified that it
        // should be disposed.
        CGContextClearRect(context, previousFrameInfo.frameRect);
    }

    // If the new frame specifies that it should not be blended with the previous image,
    // clear the part of the image the new frame covers.
    if (!frameInfo.blendWithPreviousFrame) {
        CGContextClearRect(context, frameInfo.frameRect);
    }
    [image drawAtPoint:CGPointZero];

    CGImageRef newCGImage = CGBitmapContextCreateImage(context);
    UIGraphicsEndImageContext();
    
    if (newCGImage) {
        UIImage *newImage = [UIImage imageWithCGImage:newCGImage];
        CGImageRelease(newCGImage);
        
        return newImage;
    }
    
    // Drawing the blended image failed, fallback to `image`
    return image;
}

@end
