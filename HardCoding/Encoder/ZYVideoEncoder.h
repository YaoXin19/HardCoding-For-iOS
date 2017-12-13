//
//  ZYVideoEncoder.h
//  硬编码
//
//  Created by 王志盼 on 2017/12/13.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <VideoToolbox/VideoToolbox.h>

@interface ZYVideoEncoder : NSObject
- (void)startEncoderForSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)endEncoder;
@end
