//
//  FLAnimatedImageViewTests.m
//  FLAnimatedImageDemo
//
//  Created by Hristo Hristov on 4/18/15.
//  Copyright (c) 2015 Flipboard. All rights reserved.
//

#import <Specta/Specta.h>
#import <Expecta/Expecta.h>
#import "FLAnimatedImage.h"

SpecBegin(FLAnimatedImageView)

__block FLAnimatedImage *animatedImage;
before(^{
    NSBundle *currentBundle = [NSBundle bundleForClass:[self class]];
    NSString *gifPath = [currentBundle pathForResource:@"test" ofType:@"gif"];
    NSData *gifData = [NSData dataWithContentsOfFile:gifPath];
    animatedImage = [[FLAnimatedImage alloc] initWithAnimatedGIFData:gifData];
});

describe(@"initialized animated image view", ^{
    it(@"should initialize correctly", ^{
        FLAnimatedImageView *imageView = [FLAnimatedImageView new];
        expect(imageView.animatedImage).to.beNil();
        
        imageView.animatedImage = animatedImage;
        expect(imageView.animatedImage).toNot.beNil();
        
        imageView.image = [UIImage new];
        expect(imageView.animatedImage).to.beNil();
    });
    
    it(@"should start animating image", ^{
        UIWindow *window = [UIWindow new];
        UIView *view = [UIView new];
        [window addSubview:view];
        FLAnimatedImageView *imageView = [FLAnimatedImageView new];
        imageView.animatedImage = animatedImage;
        [view addSubview:imageView];
        
    
        expect(imageView.currentFrameIndex).after(2).to.beGreaterThan(0);
    });
});


SpecEnd
