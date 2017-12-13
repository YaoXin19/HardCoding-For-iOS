//
//  ViewController.m
//  HardCoding
//
//  Created by 王志盼 on 2017/12/13.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import "ViewController.h"
#import "ZYVideoCapture.h"

@interface ViewController ()
@property (nonatomic, strong) ZYVideoCapture *videoCapture;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.videoCapture = [[ZYVideoCapture alloc] init];
    [self.videoCapture startCapture:self.view];
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.videoCapture stopCapture];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
