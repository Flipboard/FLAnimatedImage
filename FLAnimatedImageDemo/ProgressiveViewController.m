//
//  ProgressiveViewController.m
//  FLAnimatedImageDemo
//
//  Created by Geoff MacDonald on 2014-05-31.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//

#import "ProgressiveViewController.h"


#import "FLAnimatedImage.h"
#import "FLAnimatedImageView.h"
#import "DebugView.h"

#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>


@interface ProgressiveViewController ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *memoryWarningButton;
@property (nonatomic, strong) UIButton *progessiveDemoButton;

@property (nonatomic, strong) FLAnimatedImageView *imageView1;
@property (nonatomic, strong) FLAnimatedImageView *imageView2;

// Views for the debug overlay UI
@property (nonatomic, strong) DebugView *debugView1;
@property (nonatomic, strong) DebugView *debugView2;


@end


@implementation ProgressiveViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.view.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    
    self.titleLabel.frame = CGRectMake(18.0, 27.0, self.titleLabel.bounds.size.width, self.titleLabel.bounds.size.height);
    self.subtitleLabel.frame = CGRectMake(20.0, 74.0, self.subtitleLabel.bounds.size.width, self.subtitleLabel.bounds.size.height);
    self.memoryWarningButton.frame = CGRectMake(544.0, 69.0, self.memoryWarningButton.bounds.size.width, self.memoryWarningButton.bounds.size.height);
    self.progessiveDemoButton.frame = CGRectMake(544.0, 30, self.progessiveDemoButton.bounds.size.width, self.progessiveDemoButton.bounds.size.height);
    
    [self setupImages];
}

-(void)setupImages{
    
    // Setup the three `FLAnimatedImageView`s and load GIFs into them:
    
    // 1
    if (!self.imageView1) {
        self.imageView1 = [[FLAnimatedImageView alloc] init];
        self.imageView1.contentMode = UIViewContentModeScaleAspectFill;
        self.imageView1.clipsToBounds = YES;
    }
    [self.view addSubview:self.imageView1];
    self.imageView1.frame = CGRectMake(0.0, 120.0, self.view.bounds.size.width, 447.0);
    
    //set the GIF to load progressively with a URL
    FLAnimatedImage * animatedImage1 = [[FLAnimatedImage alloc] initWithURLForProgressiveGIF:[NSURL URLWithString:@"http://i.imgur.com/W1r5Fln.gif"]];
    self.imageView1.animatedImage = animatedImage1;
    
    
    // 2
    if (!self.imageView2) {
        self.imageView2 = [[FLAnimatedImageView alloc] init];
        self.imageView2.contentMode = UIViewContentModeScaleAspectFill;
        self.imageView2.clipsToBounds = YES;
    }
    [self.view addSubview:self.imageView2];
    self.imageView2.frame = CGRectMake(0.0, 577.0, self.view.bounds.size.width, 447.0);
    
    
    UIActivityIndicatorView * indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [indicator setCenter:CGPointMake(self.view.bounds.size.width/2, 250)];
    [self.imageView2 addSubview:indicator];
    [indicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        NSURL *url2 = [NSURL URLWithString:@"http://i.imgur.com/W1r5Fln.gif"];
        NSData *data2 = [NSData dataWithContentsOfURL:url2];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [indicator stopAnimating];
            
            FLAnimatedImage *animatedImage2 = [[FLAnimatedImage alloc] initWithAnimatedGIFData:data2];
            self.imageView2.animatedImage = animatedImage2;
            
            self.imageView2.delegate = self.debugView2;
            animatedImage2.delegate = self.debugView2;
            self.debugView2.imageView = self.imageView2;
            self.debugView2.image = animatedImage2;
            self.imageView2.userInteractionEnabled = YES;
        });
        
    });
    
    // Setting the delegates is for the debug UI in this demo only and is usually not needed.
    self.imageView1.delegate = self.debugView1;
    animatedImage1.delegate = self.debugView1;
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
        _subtitleLabel.text = @"Top image is progressively loaded as it downloads.";
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
        [_memoryWarningButton setTitle:@"Re-download Gifs" forState:UIControlStateNormal];
        [_memoryWarningButton addTarget:self action:@selector(redownloadGIF) forControlEvents:UIControlEventTouchUpInside];
        [_memoryWarningButton sizeToFit];
    }
    [self.view addSubview:_memoryWarningButton];
    
    return _memoryWarningButton;
}

- (UIButton *)progessiveDemoButton
{
    if (!_progessiveDemoButton) {
        _progessiveDemoButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _progessiveDemoButton.titleLabel.font = [UIFont systemFontOfSize:17.0];
        _progessiveDemoButton.tintColor = [UIColor colorWithRed:0.8 green:0.15 blue:0.15 alpha:1.0];
        [_progessiveDemoButton setTitle:@"Static Demo" forState:UIControlStateNormal];
        [_progessiveDemoButton addTarget:self action:@selector(backToStaticDemo) forControlEvents:UIControlEventTouchUpInside];
        [_progessiveDemoButton sizeToFit];
    }
    [self.view addSubview:_progessiveDemoButton];
    
    return _progessiveDemoButton;
}

-(void)backToStaticDemo{
    
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
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

-(void)redownloadGIF{
    
    [self.debugView1 removeFromSuperview];
    [self.imageView1 removeFromSuperview];
    
    self.debugView1 = nil;
    self.imageView1 = nil;
    
    [self.debugView2 removeFromSuperview];
    [self.imageView2 removeFromSuperview];
    
    self.debugView2 = nil;
    self.imageView2 = nil;
    
    [self setupImages];
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

@end
