//
//  FLAnimatedImageTests.m
//  FLAnimatedImageDemo
//
//  Created by Hristo Hristov on 4/18/15.
//  Copyright (c) 2015 Flipboard. All rights reserved.
//


#import <Specta/Specta.h>
#import <Expecta/Expecta.h>
#import "FLAnimatedImage.h"

SpecBegin(FLAnimatedImage)

__block NSData *gifData = nil;
before(^{
    NSBundle *currentBundle = [NSBundle bundleForClass:[self class]];
    NSString *gifPath = [currentBundle pathForResource:@"test" ofType:@"gif"];
    gifData = [NSData dataWithContentsOfFile:gifPath];
});

describe(@"initializations", ^{
    it(@"should initialize blank object", ^{
        FLAnimatedImage *image = [FLAnimatedImage new];
        expect(image.data).to.beNil();
        expect(image.frameCount).to.equal(0);
    });
    
    it(@"should initialize object with gif", ^{
        
        FLAnimatedImage *image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:gifData];
        expect(image.data).toNot.beNil();
        expect(image.frameCount).to.beGreaterThan(0);
        
        FLAnimatedImage *image2 = [FLAnimatedImage animatedImageWithGIFData:gifData];
        expect([image.data isEqualToData:image2.data]);
    });
    
    it(@"should return correct size for image", ^{
        FLAnimatedImage *image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:gifData];
        expect(image.size).to.equal([FLAnimatedImage sizeForImage:image]);
    });
    
    it(@"should be nil when passing invalid image data", ^{
        NSData *invalidImageData = [@"bytes" dataUsingEncoding:NSUTF8StringEncoding];
        FLAnimatedImage *image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:invalidImageData];
        expect(image).to.beNil();
    });
    
    it(@"should return zero size for invalid class", ^{
        CGSize size = [FLAnimatedImage sizeForImage:@"image"];
        expect(size).to.equal(size);
    });
});


SpecEnd

