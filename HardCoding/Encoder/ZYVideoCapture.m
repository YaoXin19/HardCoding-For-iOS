//
//  ZYVideoCapture.m
//  硬编码
//
//  Created by 王志盼 on 2017/12/13.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import "ZYVideoCapture.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "ZYVideoEncoder.h"


@interface ZYVideoCapture() <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *session;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) ZYVideoEncoder *encoder;
@end

@implementation ZYVideoCapture

- (void)startCapture:(UIView *)preView
{
    self.encoder = [[ZYVideoEncoder alloc] init];
    
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    [self.session addInput:input];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setSampleBufferDelegate:self queue:dispatch_get_global_queue(0, 0)];
    [self.session addOutput:output];
    
    //设置录制方向
    AVCaptureConnection *connect = [output connectionWithMediaType:AVMediaTypeVideo];
    [connect setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.frame = preView.bounds;
    [preView.layer insertSublayer:self.previewLayer atIndex:0];
    
    [self.session startRunning];
}

- (void)stopCapture
{
    [self.session stopRunning];
    [self.previewLayer removeFromSuperlayer];
    [self.encoder endEncoder];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    [self.encoder startEncoderForSampleBuffer:sampleBuffer];
}

@end
