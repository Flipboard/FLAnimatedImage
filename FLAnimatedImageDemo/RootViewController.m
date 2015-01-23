//
//  RootViewController.m
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//


#import "RootViewController.h"
#import "FLAnimatedImage.h"
#import "DebugView.h"


@interface RootViewController ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *memoryWarningButton;

@property (nonatomic, strong) FLAnimatedImageView *imageView1;
@property (nonatomic, strong) FLAnimatedImageView *imageView2;
@property (nonatomic, strong) FLAnimatedImageView *imageView3;

// Views for the debug overlay UI
@property (nonatomic, strong) DebugView *debugView1;
@property (nonatomic, strong) DebugView *debugView2;
@property (nonatomic, strong) DebugView *debugView3;

@end


@implementation RootViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    
    self.titleLabel.frame = CGRectMake(18.0, 27.0, self.titleLabel.bounds.size.width, self.titleLabel.bounds.size.height);
    self.subtitleLabel.frame = CGRectMake(20.0, 74.0, self.subtitleLabel.bounds.size.width, self.subtitleLabel.bounds.size.height);
    self.memoryWarningButton.frame = CGRectMake(544.0, 69.0, self.memoryWarningButton.bounds.size.width, self.memoryWarningButton.bounds.size.height);
    
    
    
    // Setup the three `FLAnimatedImageView`s and load GIFs into them:
    
    // 1
    if (!self.imageView1) {
        self.imageView1 = [[FLAnimatedImageView alloc] init];
        self.imageView1.contentMode = UIViewContentModeScaleAspectFill;
        self.imageView1.clipsToBounds = YES;
    }
    [self.view addSubview:self.imageView1];
    self.imageView1.frame = CGRectMake(0.0, 120.0, self.view.bounds.size.width, 447.0);
    
    NSURL *url1 = [[NSBundle mainBundle] URLForResource:@"rock" withExtension:@"gif"];
    NSData *data1 = [NSData dataWithContentsOfURL:url1];
    FLAnimatedImage *animatedImage1 = [FLAnimatedImage animatedImageWithGIFData:data1];
    self.imageView1.animatedImage = animatedImage1;
    
    // 2
    if (!self.imageView2) {
        self.imageView2 = [[FLAnimatedImageView alloc] init];
        self.imageView2.contentMode = UIViewContentModeScaleAspectFill;
        self.imageView2.clipsToBounds = YES;
    }
    [self.view addSubview:self.imageView2];
    self.imageView2.frame = CGRectMake(0.0, 577.0, 379.0, 447.0);
    
    FLAnimatedImage * __block animatedImage2 = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url2 = [NSURL URLWithString:@"http://raphaelschaad.com/static/nyan.gif"];
        NSData *data2 = [NSData dataWithContentsOfURL:url2];
        animatedImage2 = [FLAnimatedImage animatedImageWithGIFData:data2];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView2.animatedImage = animatedImage2;
            
            // Set up debug UI for image 2
            self.imageView2.debug_delegate = self.debugView2;
            animatedImage2.debug_delegate = self.debugView2;
            self.debugView2.imageView = self.imageView2;
            self.debugView2.image = animatedImage2;
            self.imageView2.userInteractionEnabled = YES;
        });
    });
    
    // 3
    if (!self.imageView3) {
        self.imageView3 = [[FLAnimatedImageView alloc] init];
        self.imageView3.contentMode = UIViewContentModeScaleAspectFill;
        self.imageView3.clipsToBounds = YES;
    }
    [self.view addSubview:self.imageView3];
    self.imageView3.frame = CGRectMake(389.0, 577.0, 379.0, 447.0);
    
    FLAnimatedImage * __block animatedImage3 = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url3 = [NSURL URLWithString:@"http://upload.wikimedia.org/wikipedia/commons/2/2c/Rotating_earth_%28large%29.gif"];
        NSData *data3 = [NSData dataWithContentsOfURL:url3];
        animatedImage3 = [FLAnimatedImage animatedImageWithGIFData:data3];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView3.animatedImage = animatedImage3;
            
            // Set up debug UI for image 3
            self.imageView3.debug_delegate = self.debugView3;
            animatedImage3.debug_delegate = self.debugView3;
            self.debugView3.imageView = self.imageView3;
            self.debugView3.image = animatedImage3;
            self.imageView3.userInteractionEnabled = YES;
        });
    });
    
    // ... that's it!
    
    
    
    // Setting the delegates is for the debug UI in this demo only and is usually not needed.
    self.imageView1.debug_delegate = self.debugView1;
    animatedImage1.debug_delegate = self.debugView1;
    self.debugView1.imageView = self.imageView1;
    self.debugView1.image = animatedImage1;
    self.imageView1.userInteractionEnabled = YES;
}


#pragma mark -

- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:31.0];
        _titleLabel.textColor = [UIColor colorWithWhite:0.05 alpha:1.0];
        _titleLabel.text = @"FLAnimatedImage Demo Player";
        [_titleLabel sizeToFit];
    }
    _titleLabel.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:_titleLabel];
    
    return _titleLabel;
}


- (UILabel *)subtitleLabel
{
    if (!_subtitleLabel) {
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:17.0];
        _subtitleLabel.textColor = [UIColor colorWithWhite:0.05 alpha:1.0];
        _subtitleLabel.text = @"Cache sizes are optimized individually for each image.";
        [_subtitleLabel sizeToFit];
    }
    _subtitleLabel.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:_subtitleLabel];
    
    return _subtitleLabel;
}


- (UIButton *)memoryWarningButton
{
    if (!_memoryWarningButton) {
        _memoryWarningButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _memoryWarningButton.titleLabel.font = [UIFont systemFontOfSize:17.0];
        _memoryWarningButton.tintColor = [UIColor colorWithRed:0.8 green:0.15 blue:0.15 alpha:1.0];
        [_memoryWarningButton setTitle:@"Simulate Memory Warning" forState:UIControlStateNormal];
        [_memoryWarningButton addTarget:[UIApplication sharedApplication] action:@selector(_performMemoryWarning) forControlEvents:UIControlEventTouchUpInside];
        [_memoryWarningButton sizeToFit];
    }
    [self.view addSubview:_memoryWarningButton];
    
    return _memoryWarningButton;
}


- (DebugView *)debugView1
{
    if (!_debugView1) {
        _debugView1 = [[DebugView alloc] init];
    }
    [self.imageView1 addSubview:_debugView1];
    _debugView1.frame = self.imageView1.bounds;
    
    return _debugView1;
}


- (DebugView *)debugView2
{
    if (!_debugView2) {
        _debugView2 = [[DebugView alloc] init];
        _debugView2.style = DebugViewStyleCondensed;
    }
    [self.imageView2 addSubview:_debugView2];
    _debugView2.frame = self.imageView2.bounds;
    
    return _debugView2;
}


- (DebugView *)debugView3
{
    if (!_debugView3) {
        _debugView3 = [[DebugView alloc] init];
        _debugView3.style = DebugViewStyleCondensed;
    }
    [self.imageView3 addSubview:_debugView3];
    _debugView3.frame = self.imageView3.bounds;
    
    return _debugView3;
}


@end
