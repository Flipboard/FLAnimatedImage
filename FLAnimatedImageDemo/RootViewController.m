//
//  RootViewController.m
//  FLAnimatedImageDemo
//
//  Created by Raphael Schaad on 4/1/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//


#import "RootViewController.h"
#import <FLAnimatedImage/FLAnimatedImage.h>
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

// Internal properties on FLAnimatedImage and FLAnimatedImageView, only availabe in debug and used exclusively for the sample project.
#if defined(DEBUG) && DEBUG

@interface FLAnimatedImage (Private)
@property (nonatomic, weak) id debug_delegate;
@end

@implementation FLAnimatedImage (Private)
@dynamic debug_delegate;
@end

@interface FLAnimatedImageView (Private)
@property (nonatomic, weak) id debug_delegate;
@end

@implementation FLAnimatedImageView (Private)
@dynamic debug_delegate;
@end

#endif


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
    
    NSURL *url2 = [NSURL URLWithString:@"https://cloud.githubusercontent.com/assets/1567433/10417835/1c97e436-7052-11e5-8fb5-69373072a5a0.gif"];
    [self loadAnimatedImageWithURL:url2 completion:^(FLAnimatedImage *animatedImage) {
        self.imageView2.animatedImage = animatedImage;

        // Set up debug UI for image 2
#if defined(DEBUG) && DEBUG
        self.imageView2.debug_delegate = self.debugView2;
        animatedImage.debug_delegate = self.debugView2;
#endif
        self.debugView2.imageView = self.imageView2;
        self.debugView2.image = animatedImage;
        self.imageView2.userInteractionEnabled = YES;
    }];
    
    // 3
    if (!self.imageView3) {
        self.imageView3 = [[FLAnimatedImageView alloc] init];
        self.imageView3.contentMode = UIViewContentModeScaleAspectFill;
        self.imageView3.clipsToBounds = YES;
    }
    [self.view addSubview:self.imageView3];
    self.imageView3.frame = CGRectMake(389.0, 577.0, 379.0, 447.0);
    
    NSURL *url3 = [NSURL URLWithString:@"https://upload.wikimedia.org/wikipedia/commons/2/2c/Rotating_earth_%28large%29.gif"];
    [self loadAnimatedImageWithURL:url3 completion:^(FLAnimatedImage *animatedImage) {
        self.imageView3.animatedImage = animatedImage;

        // Set up debug UI for image 3
#if defined(DEBUG) && DEBUG
        self.imageView3.debug_delegate = self.debugView3;
        animatedImage.debug_delegate = self.debugView3;
#endif
        self.debugView3.imageView = self.imageView3;
        self.debugView3.image = animatedImage;
        self.imageView3.userInteractionEnabled = YES;
    }];
    
    // ... that's it!
    
    
    
    // Setting the delegates is for the debug UI in this demo only and is usually not needed.
#if defined(DEBUG) && DEBUG
    self.imageView1.debug_delegate = self.debugView1;
    animatedImage1.debug_delegate = self.debugView1;
#endif
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

/// Even though NSURLCache *may* cache the results for remote images, it doesn't guarantee it.
/// Cache control headers or internal parts of NSURLCache's implementation may cause these images to become uncache.
/// Here we enfore strict disk caching so we're sure the images stay around.
- (void)loadAnimatedImageWithURL:(NSURL *const)url completion:(void (^)(FLAnimatedImage *animatedImage))completion
{
    NSString *const filename = url.lastPathComponent;
    NSString *const diskPath = [NSHomeDirectory() stringByAppendingPathComponent:filename];
    
    NSData * __block animatedImageData = [[NSFileManager defaultManager] contentsAtPath:diskPath];
    FLAnimatedImage * __block animatedImage = [[FLAnimatedImage alloc] initWithAnimatedGIFData:animatedImageData];
    
    if (animatedImage) {
        if (completion) {
            completion(animatedImage);
        }
    } else {
        [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            animatedImageData = data;
            animatedImage = [[FLAnimatedImage alloc] initWithAnimatedGIFData:animatedImageData];
            if (animatedImage) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(animatedImage);
                    });
                }
                [data writeToFile:diskPath atomically:YES];
            }
        }] resume];
    }
}


@end
