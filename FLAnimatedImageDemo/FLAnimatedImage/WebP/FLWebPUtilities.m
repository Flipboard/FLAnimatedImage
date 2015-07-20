//
//  FLWebPUtilities.m
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLWebPUtilities.h"

#import <UIKit/UIKit.h>

#import <libwebp/decode.h>

#ifndef BYTE_SIZE
#define BYTE_SIZE 8 // byte size in bits
#endif

CGImageRef FLWebPCreateCGImageWithBytes(const void *bytes, size_t length, CGRect frameRect, CGRect imageRect)
{
    // If the frame is not contained in the full image rect, this method would copy image data into
    // random memory locations, which is obviously very bad. Just return NULL if this happens.
    if (!CGRectContainsRect(imageRect, frameRect)) {
        return NULL;
    }

    CGImageRef image = NULL;
    WebPDecoderConfig config;

    if (bytes && length > 0 && WebPInitDecoderConfig(&config)) {
        if (WebPGetFeatures(bytes, length, &config.input) == VP8_STATUS_OK) {
            // Ask UIKit to create a CGBitmapContext in the system's native format (32-bit premult BGRA aligned to 32 bytes per row)
            UIGraphicsBeginImageContextWithOptions(imageRect.size, NO, 1.0);
            CGContextRef context = UIGraphicsGetCurrentContext();

            if (context) {
                // Tell WebP to decode to the native image format (BGRA)
                config.output.colorspace = MODE_bgrA;

                size_t bytesPerPixel = CGBitmapContextGetBitsPerPixel(context) / BYTE_SIZE;
                size_t bytesPerRow = CGBitmapContextGetBytesPerRow(context);
                size_t dataOffset = (frameRect.origin.y * bytesPerRow) + (frameRect.origin.x * bytesPerPixel);
                config.output.u.RGBA.rgba   = (uint8_t *)CGBitmapContextGetData(context) + dataOffset;
                config.output.u.RGBA.stride = (int)CGBitmapContextGetBytesPerRow(context);
                config.output.u.RGBA.size   = CGBitmapContextGetBytesPerRow(context) * frameRect.size.height;
                config.output.is_external_memory = 1;

                if (WebPDecode(bytes, length, &config) == VP8_STATUS_OK) {
                    image = CGBitmapContextCreateImage(context);
                }
            }

            UIGraphicsEndImageContext();
        }
    }

    return image;
}
