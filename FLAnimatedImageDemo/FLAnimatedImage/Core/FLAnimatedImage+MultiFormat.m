//
//  FLAnimatedImage+MultiFormat.m
//  Douban
//
//  Created by ly on 7/13/16.
//  Copyright © 2016 Douban. All rights reserved.
//

#import "FLAnimatedImage+MultiFormat.h"
#import "FLAnimatedImage+GIF.h"

#if defined(FL_WEBP) && FL_WEBP
#import "FLAnimatedImage+WebP.h"
#endif

@implementation FLAnimatedImage (MultiFormat)

+ (FLAnimatedImage *)animatedImageWithData:(NSData *)data
{
	NSString *type = [self contentTypeForImageData:data];

	FLAnimatedImage *image = nil;
	if ([type isEqualToString:@"image/gif"]) {
		image = [FLAnimatedImage animatedImageWithGIFData:data];
	} else if ([type isEqualToString:@"image/webp"]) {
#if defined(FL_WEBP) && FL_WEBP
		image = [FLAnimatedImage animatedImageWithWebPData:data];
#endif
	}

	return image;
}

// Copy from SDWebImage: https://github.com/rs/SDWebImage/blob/master/SDWebImage/NSData+ImageContentType.m
+ (NSString *)contentTypeForImageData:(NSData *)data
{
	uint8_t c;
	[data getBytes:&c length:1];
	switch (c) {
		case 0xFF:
			return @"image/jpeg";
		case 0x89:
			return @"image/png";
		case 0x47:
			return @"image/gif";
		case 0x49:
		case 0x4D:
			return @"image/tiff";
		case 0x52:
			// R as RIFF for WEBP
			if ([data length] < 12) {
				return nil;
			}

			NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
			if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
				return @"image/webp";
			}

			return nil;
	}
	return nil;
}

@end
