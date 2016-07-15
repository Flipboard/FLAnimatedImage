//
//  FLWebPUtilities.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus
extern “C” {
#endif

/**
 * Create a CGImageRef given the bytes and length from a WebP frame.
 * Note that this image is not yet ready to be displayed to the user, it may first need to be
 * blended on top of a previous frame.
 * frameRect - Each frame of a WebP image may specify its width/height and x/y offset.
 *             This is the rectangle that this frame will actually cover.
 * imageRect - The full size of the WebP image. This is how large the returned CGImageRef will be.
 */
extern CGImageRef FLWebPCreateCGImageWithBytes(const void *bytes, size_t length, CGRect frameRect, CGRect imageRect) CF_RETURNS_RETAINED;

#ifdef __cplusplus
}
#endif
