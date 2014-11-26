//
//  RootViewController.m
//  FLAnimatedImageDemo
//
//  Created by David Kasper on 11/24/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//

#import "RootViewController.h"
#import "ObjCViewController.h"
#import "SwiftViewController.h"

#define BUTTON_HEIGHT 20

@interface RootViewController ()

@property (nonatomic, strong) UIButton *objCButton;
@property (nonatomic, strong) UIButton *swiftButton;

@end

@implementation RootViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        _objCButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_objCButton setTitle:@"Objective-C" forState:UIControlStateNormal];
        [_objCButton addTarget:self action:@selector(objc:) forControlEvents:UIControlEventTouchUpInside];
        
        _swiftButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_swiftButton setTitle:@"Swift" forState:UIControlStateNormal];
        [_swiftButton addTarget:self action:@selector(swift:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.objCButton.frame = CGRectMake(0, CGRectGetMaxY(self.navigationController.navigationBar.frame), self.view.bounds.size.width, BUTTON_HEIGHT);
    self.swiftButton.frame = CGRectMake(0, CGRectGetMaxY(self.objCButton.frame), self.view.bounds.size.width, BUTTON_HEIGHT);
    
    [self.view addSubview:self.objCButton];
    [self.view addSubview:self.swiftButton];
}

- (void)objc:(id)sender {
    [self.navigationController pushViewController:[[ObjCViewController alloc] init] animated:YES];
}

- (void)swift:(id)sender {
    [self.navigationController pushViewController:[[SwiftViewController alloc] init] animated:YES];
}

@end
