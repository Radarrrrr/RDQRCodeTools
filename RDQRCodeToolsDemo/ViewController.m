//
//  ViewController.m
//  RDQRCodeToolsDemo
//
//  Created by radar on 2018/3/28.
//  Copyright © 2018年 radar. All rights reserved.
//

#import "ViewController.h"
#import "RDQRCodeScaner.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //写一个按钮入口
    UIButton *pushBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    pushBtn.frame = CGRectMake(0, 0, 100, 100);
    pushBtn.backgroundColor = [UIColor lightGrayColor];
    pushBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [pushBtn setTitle:@"LOAD" forState:UIControlStateNormal];
    [pushBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [pushBtn addTarget:self action:@selector(pushAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pushBtn];
    
}

- (void)pushAction:(id)sender
{
    [RDQRCodeScaner pushToOpenScanner:self.navigationController completion:^(NSString *qrcode) {
        NSLog(@"扫码器返回二维码: %@", qrcode);
    }];
}


@end
