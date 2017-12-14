//
//  ZYVideoEncoder.m
//  硬编码
//
//  Created by 王志盼 on 2017/12/13.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import "ZYVideoEncoder.h"
@interface ZYVideoEncoder()

/**
 记录当前帧数
 */
@property (nonatomic, assign) NSInteger frameID;


/**
 编码会话
 */
@property (nonatomic, assign) VTCompressionSessionRef compressionSession;


/**
 文件句柄
 */
@property (nonatomic, strong) NSFileHandle *fileHandle;
@end


@implementation ZYVideoEncoder

- (instancetype)init
{
    if (self = [super init])
    {
        //初始化写入文件
        [self setupFileHandle];
        
        //初始化编码会话
        [self setupVideoSession];
    }
    return self;
}


- (void)setupFileHandle
{
    NSFileManager *mgr = [NSFileManager defaultManager];
    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"abc.mp4"];
    
    //移除原有文件
    [mgr removeItemAtPath:filePath error:nil];
    [mgr createFileAtPath:filePath contents:nil attributes:nil];
    
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
}

- (void)setupVideoSession
{
    //用于记录当前是第几帧数据
    self.frameID = 0;
    
    //录制视频的宽高
    int width = [UIScreen mainScreen].bounds.size.width;
    int height = [UIScreen mainScreen].bounds.size.height;
    
    // 创建CompressionSession对象,该对象用于对画面进行编码
    // kCMVideoCodecType_H264 : 表示使用h.264进行编码
    // finishCompressH264Callback : 当一次编码结束会在该函数进行回调,可以在该函数中将数据,写入文件中
    //传入的self，就是finishCompressH264Callback回调函数里面的outputCallbackRefCon，通过bridge就可以取出此self
    VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, finishCompressH264Callback, (__bridge void * _Nullable)(self), &_compressionSession);
    
    //设置实时编码，直播必然是实时输出
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    //设置期望帧数，每秒多少帧，一般都是30帧以上，以免画面卡顿
    int fps = 30;
    CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &fps);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
    
    //设置码率(码率: 编码效率, 码率越高,则画面越清晰, 如果码率较低会引起马赛克 --> 码率高有利于还原原始画面,但是也不利于传输)
    int bitRate = 800 * 1024;
    CFNumberRef rateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, rateRef);
    NSArray *limit = @[@(bitRate * 1.5/8), @(1)];
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    
    //设置关键帧间隔（也就是GOP间隔）
    //这里设置与上面的fps一致，意味着每间隔30帧开始一个新的GOF序列，也就是每隔间隔1s生成新的GOF序列
    //因为上面设置的是，一秒30帧
    int frameInterval = 30;
    CFNumberRef intervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &frameInterval);
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, intervalRef);
    
    //设置结束，准备编码
    VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
}

#pragma mark - private

// 编码完成回调
void finishCompressH264Callback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer)
{
    if (status != noErr) return;
    
    //根据传入的参数获取对象
    ZYVideoEncoder *encoder = (__bridge ZYVideoEncoder *)(outputCallbackRefCon);
    
    //判断是否是关键帧
    bool isKeyFrame = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    //如果是关键帧，获取sps & pps数据
    if (isKeyFrame)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        //获取sps信息
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        
        // 获取PPS信息
        size_t pparameterSetSize, pparameterSetCount;
        const uint8_t *pparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
        
        // 装sps/pps转成NSData，以方便写入文件
        NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
        NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
        
        // 写入文件
        [encoder gotSpsPps:sps pps:pps];
    }
    
    //获取数据块
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    
    if (statusCodeRet == noErr)
    {
        size_t bufferOffset = 0;
        // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        static const int AVCCHeaderLength = 4;
        
        //循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength)
        {
            uint32_t NALUnitLength = 0;
            
            //读取NAL单元长度
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder gotEncodedData:data isKeyFrame:isKeyFrame];
            
            // 移动到写一个块，转成NALU单元
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
    }
}

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    // 拼接NALU的header
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    
    // 将NALU的头&NALU的体写入文件
    [self.fileHandle writeData:ByteHeader];
    [self.fileHandle writeData:sps];
    [self.fileHandle writeData:ByteHeader];
    [self.fileHandle writeData:pps];
    
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
    if (self.fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [self.fileHandle writeData:ByteHeader];
        [self.fileHandle writeData:data];
    }
}


#pragma mark -开始结束方法
- (void)startEncoderForSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    //将sampleBuffer转为imageBuffer
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    
    //根据当前帧率，创建CMTime的时间
    CMTime presentationTimeStamp = CMTimeMake(self.frameID++, 1000);
    
    VTEncodeInfoFlags flags;
    
    //开始编码该帧数据
    OSStatus status = VTCompressionSessionEncodeFrame(self.compressionSession,
                                                      imageBuffer,
                                                      presentationTimeStamp,
                                                      kCMTimeInvalid,
                                                      NULL,
                                                      (__bridge void * _Nullable)(self),
                                                      &flags);
    
    if (status == noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    }
}

- (void)endEncoder
{
    VTCompressionSessionCompleteFrames(self.compressionSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(self.compressionSession);
    CFRelease(self.compressionSession);
    self.compressionSession = NULL;
}
@end
