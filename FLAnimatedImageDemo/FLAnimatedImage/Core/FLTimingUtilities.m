//
//  FLTimingUtilities.m
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

#import "FLTimingUtilities.h"
#import "FLAnimatedImage.h"

const NSTimeInterval kDelayTimeIntervalMinimum = 0.02;
const NSTimeInterval kDelayTimeIntervalDefault = 0.1;

NSNumber *FLDelayTimeFloor(NSNumber *delayTime, NSUInteger frameIndex)
{
	
	// To support the minimum even when rounding errors occur, use an epsilon when comparing. We downcast to float because that's what we get for delayTime from ImageIO.
	if ([delayTime floatValue] < ((float)kDelayTimeIntervalMinimum - FLT_EPSILON)) {
		FLLogInfo(@"Rounding frame %zu's `delayTime` from %f up to default %f (minimum supported: %f).", (unsigned long)frameIndex, [delayTime floatValue], kDelayTimeIntervalDefault, kDelayTimeIntervalMinimum);
		return @(kDelayTimeIntervalDefault);
	}
	return delayTime;
}
