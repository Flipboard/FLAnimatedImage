//
//  FLTimingUtilities.h
//  Facebook
//
//  Created by Ben Hiller.
//  Copyright (c) 2014-2015 Facebook. All rights reserved.
//

// If a frame has a delay time less than kDelayTimeIntervalMinimum, we instead use kDelayTimeIntervalDefault as the
// delay time, as it is assumed that that delay time is unintentional. This is consistent with how browsers behave.
// See the comments on FLDelayTimeFloor for more details.
extern const NSTimeInterval kDelayTimeIntervalMinimum;
extern const NSTimeInterval kDelayTimeIntervalDefault;


// Support frame delays as low as `kDelayTimeIntervalMinimum`, with anything below being rounded up to `kDelayTimeIntervalDefault` for legacy compatibility.
// This is how the fastest browsers do it as per 2012: http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser-compatibility
extern NSNumber *FLDelayTimeFloor(NSNumber *delayTime, NSUInteger frameIndex);
