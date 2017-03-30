//
//  XDXRecoder.m
//  XDXPCMToAACDemo
//
//  Created by demon on 23/03/2017.
//
//



/*******************************************************************************************/

    //  详细解析请参考博客：chengyangli.github.io
    //  简书:

/*******************************************************************************************/

#import "XDXRecoder.h"
#import <unistd.h>
#import <mach/mach_time.h>
#import <CoreMedia/CMSync.h>
#import "XDXDateTool.h"
#import <AudioToolbox/AudioToolbox.h>

float   g_avtimfdiff = 0;
Float64 g_vstarttime = 0.0;
#define kBufferDurationSeconds .5
#define kXDXAnyWhereVoiceDemoPathComponent "VoiceDemo"

//voice memos Macro
#ifdef __XDX_VICE_FEATURE__
#include "XDXCommonDef.h"
#define kAudioStoreFileExtend "caf"
#endif

//XDXVOIPMessageQueue collectPcmQueue;

AudioConverterRef               _encodeConvertRef;  ///< convert param
AudioStreamBasicDescription     _targetDes;         ///< destination format

AudioBufferList* convertPCMToAAC (AudioQueueBufferRef inBuffer, XDXRecorder *recoder);

#pragma mark - CallBack : collect pcm and  convert
static void inputBufferHandler(void *                                 inUserData,
                               AudioQueueRef                          inAQ,
                               AudioQueueBufferRef                    inBuffer,
                               const AudioTimeStamp *                 inStartTime,
                               UInt32                                 inNumPackets,
                               const AudioStreamPacketDescription*	  inPacketDesc) {
    XDXRecorder *recoder        = (__bridge XDXRecorder *)inUserData;
    
    /*
     inNumPackets 总包数：音频队列缓冲区大小 （在先前估算缓存区大小为2048）/ （dataFormat.mFramesPerPacket (采集数据每个包中有多少帧，此处在初始化设置中为1) * dataFormat.mBytesPerFrame（每一帧中有多少个字节，此处在初始化设置中为每一帧中两个字节）），所以用捕捉PCM数据时inNumPackets为1024。
     注意：如果采集的数据是PCM需要将dataFormat.mFramesPerPacket设置为1，而本例中最终要的数据为AAC,在AAC格式下需要将mFramesPerPacket设置为1024.也就是采集到的inNumPackets为1，所以inNumPackets这个参数在此处可以忽略，因为在转换器中传入的inNumPackets应该为AAC格式下默认的1，在此后写入文件中也应该传的是转换好的inNumPackets。
     */
    
    // collect pcm data，可以在此存储
    
    AudioBufferList *bufferList = convertPCMToAAC(inBuffer, recoder);
    
    // free memory
    free(bufferList->mBuffers[0].mData);
    free(bufferList);
    // begin write audio data for record audio only
    
    // 出队
    AudioQueueRef queue = recoder.mQueue;
    if (recoder.isRunning) {
        AudioQueueEnqueueBuffer(queue, inBuffer, 0, NULL);
    }
}

OSStatus encodeConverterComplexInputDataProc(AudioConverterRef              inAudioConverter,
                                             UInt32                         *ioNumberDataPackets,
                                             AudioBufferList                *ioData,
                                             AudioStreamPacketDescription   **outDataPacketDescription,
                                             void                           *inUserData) {
    
    ioData->mBuffers[0].mData           = inUserData;
    ioData->mBuffers[0].mNumberChannels = _targetDes.mChannelsPerFrame;
    ioData->mBuffers[0].mDataByteSize   = 1024*2; // 2 为dataFormat.mBytesPerFrame 每一帧的比特数
    
    return 0;
}

// PCM -> AAC
AudioBufferList* convertPCMToAAC (AudioQueueBufferRef inBuffer, XDXRecorder *recoder) {
    
    UInt32   maxPacketSize    = 0;
    UInt32   size             = sizeof(maxPacketSize);
    OSStatus status;
    
    status = AudioConverterGetProperty(_encodeConvertRef,
                                       kAudioConverterPropertyMaximumOutputPacketSize,
                                       &size,
                                       &maxPacketSize);
//    log4cplus_info("AudioConverter","kAudioConverterPropertyMaximumOutputPacketSize status:%d \n",(int)status);
    
    AudioBufferList *bufferList             = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers              = 1;
    bufferList->mBuffers[0].mNumberChannels = _targetDes.mChannelsPerFrame;
    bufferList->mBuffers[0].mData           = malloc(maxPacketSize);
    bufferList->mBuffers[0].mDataByteSize   = inBuffer->mAudioDataByteSize;
    
    AudioStreamPacketDescription outputPacketDescriptions;
    
    // inNumPackets设置为1表示编码产生1帧数据即返回，官方：On entry, the capacity of outOutputData expressed in packets in the converter's output format. On exit, the number of packets of converted data that were written to outOutputData. 在输入表示输出数据的最大容纳能力 在转换器的输出格式上，在转换完成时表示多少个包被写入
    UInt32 inNumPackets = 1;
    // inNumPackets设置为1表示编码产生1帧数据即返回
    status = AudioConverterFillComplexBuffer(_encodeConvertRef,
                                             encodeConverterComplexInputDataProc,
                                             inBuffer->mAudioData,
                                             &inNumPackets,
                                             bufferList,
                                             &outputPacketDescriptions);
//    log4cplus_info("AudioConverter","set AudioConverterFillComplexBuffer status:%d",(int)status);
    
    if (recoder.needsVoiceDemo)
    {
        // if inNumPackets set not correct, file will not normally play. 将转换器转换出来的包写入文件中，inNumPackets表示写入文件的起始位置
        OSStatus status = AudioFileWritePackets(recoder.mRecordFile,
                                                FALSE,
                                                bufferList->mBuffers[0].mDataByteSize,
                                                &outputPacketDescriptions,
                                                recoder.mRecordPacket,
                                                &inNumPackets,
                                                bufferList->mBuffers[0].mData);
//        log4cplus_info("write file","write file status = %d",(int)status);
        recoder.mRecordPacket += inNumPackets;
    }
    
    return bufferList;
}

@interface XDXRecorder()

-(void)setUpRecoderWithFormatID:(UInt32) formatID;

-(int)computeRecordBufferSizeFrom:(const AudioStreamBasicDescription *) format andDuration:(float) seconds;

-(void)copyEncoderCookieToFile;

@end


@implementation XDXRecorder
@synthesize delegate;
@synthesize isRunning;
@synthesize dataFormat;
@synthesize startTime;
@synthesize mQueue;
@synthesize rawFilePath;
@synthesize hostTime;
@synthesize mRecordFile;
@synthesize mRecordPacket;
@synthesize needsVoiceDemo = mNeedsVoiceDemo;
#pragma mark private
#pragma mark-------------------------------------------------------------------------------------------------------
// if collect CBR needn't set magic cookie , if collect VBR should set magic cookie, if needn't to convert format that can be setting by audio queue directly.
-(void)copyEncoderCookieToFile
{
    // Grab the cookie from the converter and write it to the destination file.
    UInt32 cookieSize = 0;
    OSStatus error = AudioConverterGetPropertyInfo(_encodeConvertRef, kAudioConverterCompressionMagicCookie, &cookieSize, NULL);
    
    // If there is an error here, then the format doesn't have a cookie - this is perfectly fine as som formats do not.
//    log4cplus_info("cookie","cookie status:%d %d",(int)error, cookieSize);
    if (error == noErr && cookieSize != 0) {
        char *cookie = (char *)malloc(cookieSize * sizeof(char));
        //        UInt32 *cookie = (UInt32 *)malloc(cookieSize * sizeof(UInt32));
        error = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCompressionMagicCookie, &cookieSize, cookie);
//        log4cplus_info("cookie","cookie size status:%d",(int)error);
        
        if (error == noErr) {
            error = AudioFileSetProperty(mRecordFile, kAudioFilePropertyMagicCookieData, cookieSize, cookie);
//            log4cplus_info("cookie","set cookie status:%d ",(int)error);
            if (error == noErr) {
                UInt32 willEatTheCookie = false;
                error = AudioFileGetPropertyInfo(mRecordFile, kAudioFilePropertyMagicCookieData, NULL, &willEatTheCookie);
                printf("Writing magic cookie to destination file: %u\n   cookie:%d \n", (unsigned int)cookieSize, willEatTheCookie);
            } else {
                printf("Even though some formats have cookies, some files don't take them and that's OK\n");
            }
        } else {
            // If there is an error here, then the format doesn't have a cookie - this is perfectly fine as som formats do not.
            printf("Could not Get kAudioConverterCompressionMagicCookie from Audio Converter!\n");
        }
        
        free(cookie);
    }
}


-(void)setUpRecoderWithFormatID:(UInt32)formatID
{
    //setup auido sample rate, channel number, and format ID
    memset(&dataFormat, 0, sizeof(dataFormat));
    
    UInt32 size = sizeof(dataFormat.mSampleRate);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                            &size,
                            &dataFormat.mSampleRate);
    dataFormat.mSampleRate = 44100.0;
    
    size = sizeof(dataFormat.mChannelsPerFrame);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels,
                            &size,
                            &dataFormat.mChannelsPerFrame);
    dataFormat.mFormatID = formatID;
    
    if (formatID == kAudioFormatLinearPCM)
    {
        dataFormat.mFormatFlags     = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        dataFormat.mBitsPerChannel  = 16;
        dataFormat.mBytesPerPacket  = dataFormat.mBytesPerFrame = (dataFormat.mBitsPerChannel / 8) * dataFormat.mChannelsPerFrame;
        dataFormat.mFramesPerPacket = 1; // 用AudioQueue采集pcm需要这么设置
    }
}

-(int)computeRecordBufferSizeFrom:(const AudioStreamBasicDescription *) format andDuration:(float) seconds
{
    int packets = 0;
    int frames  = 0;
    int bytes   = 0;
    
    frames = (int)ceil(seconds * format->mSampleRate);
    
    if (format->mBytesPerFrame > 0)
        bytes = frames * format->mBytesPerFrame;
    else {
        UInt32 maxPacketSize;
        if (format->mBytesPerPacket > 0)
            maxPacketSize = format->mBytesPerPacket;	// constant packet size
        else {
            UInt32 propertySize = sizeof(maxPacketSize);
            OSStatus status     = AudioQueueGetProperty(mQueue,
                                                        kAudioQueueProperty_MaximumOutputPacketSize,
                                                        &maxPacketSize,
                                                        &propertySize);
        }
        
        if (format->mFramesPerPacket > 0)
            packets = frames / format->mFramesPerPacket;
        else
            packets = frames;	// worst-case scenario: 1 frame in a packet
        if (packets == 0)		// sanity check
            packets = 1;
        bytes = packets * maxPacketSize;
    }
    
    return bytes;
}

// 转码器基本信息设置
- (void)convertBasicSetting {
    // 此处目标格式其他参数均为默认，系统会自动计算，否则无法进入encodeConverterComplexInputDataProc回调
    AudioStreamBasicDescription sourceDes = dataFormat;
    AudioStreamBasicDescription targetDes;
    
    memset(&targetDes, 0, sizeof(targetDes));
    targetDes.mFormatID                   = kAudioFormatMPEG4AAC;
    targetDes.mSampleRate                 = 44100.0;
    targetDes.mChannelsPerFrame           = dataFormat.mChannelsPerFrame;
    targetDes.mFramesPerPacket            = 1024;
    
    OSStatus status     = 0;
    UInt32 targetSize   = sizeof(targetDes);
    status              = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &targetSize, &targetDes);
    //    log4cplus_info("pcm", "create target data format status:%d",(int)status);
    
    memset(&_targetDes, 0, sizeof(_targetDes));
    memcpy(&_targetDes, &targetDes, targetSize);
    
    // 选择软件编码
    AudioClassDescription audioClassDes;
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                        sizeof(targetDes.mFormatID),
                                        &targetDes.mFormatID,
                                        &targetSize);
    //    log4cplus_info("pcm","get kAudioFormatProperty_Encoders status:%d",(int)status);
    
    UInt32 numEncoders = targetSize/sizeof(AudioClassDescription);
    AudioClassDescription audioClassArr[numEncoders];
    AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                           sizeof(targetDes.mFormatID),
                           &targetDes.mFormatID,
                           &targetSize,
                           audioClassArr);
    //    log4cplus_info("pcm","wrirte audioClassArr status:%d",(int)status);
    
    for (int i = 0; i < numEncoders; i++) {
        if (audioClassArr[i].mSubType == kAudioFormatMPEG4AAC && audioClassArr[i].mManufacturer == kAppleSoftwareAudioCodecManufacturer) {
            memcpy(&audioClassDes, &audioClassArr[i], sizeof(AudioClassDescription));
            break;
        }
    }
    
    status          = AudioConverterNewSpecific(&sourceDes, &targetDes, 1,
                                                &audioClassDes, &_encodeConvertRef);
    //    log4cplus_info("pcm","new convertRef status:%d",(int)status);
    
    targetSize      = sizeof(sourceDes);
    status          = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentInputStreamDescription, &targetSize, &sourceDes);
    //    log4cplus_info("pcm","get sourceDes status:%d",(int)status);
    
    targetSize      = sizeof(targetDes);
    status          = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentOutputStreamDescription, &targetSize, &targetDes);
    //    log4cplus_info("pcm","get targetDes status:%d",(int)status);
    
    // 设置码率，需要和采样率对应
    UInt32 bitRate  = 64000;
    targetSize      = sizeof(bitRate);
    status          = AudioConverterSetProperty(_encodeConvertRef,
                                                kAudioConverterEncodeBitRate,
                                                targetSize, &bitRate);
    //    log4cplus_info("pcm","set covert property bit rate status:%d",(int)status);
}

#pragma mark public
#pragma mark--------------------------------------------------------------------------------------------------------

-(id)initWithFormatID:(UInt32)formatID
{
    if (self = [super init]) {
        isRunning = NO;
        
        NSArray *searchPaths        = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *ituneShareDir     = searchPaths[0];
        NSString *documentPath      = [ituneShareDir stringByAppendingPathComponent:@kXDXAnyWhereVoiceDemoPathComponent];
        
        NSFileManager *fileManager  = [NSFileManager defaultManager];
        NSError *error              = nil;
        
        if ([fileManager fileExistsAtPath:documentPath] == NO)
        {
            [fileManager createDirectoryAtPath:documentPath withIntermediateDirectories:NO attributes:nil error:&error];
        }
        
        mNeedsVoiceDemo = NO;
    }
    
    return self;
}

-(void)stopRecorder
{
    if (isRunning == NO) {
//        log4cplus_info("pcm", "Stop recorder repeat");
        return;
    }
    
//    log4cplus_info("pcm","stop pcm encoder");
    
    isRunning = NO;
    if (mQueue) {
        OSStatus stopRes = AudioQueueStop(mQueue, true);
        [self copyEncoderCookieToFile];
        
        if (stopRes == noErr){
            for (int i = 0; i < kNumberQueueBuffers; i++)
                AudioQueueFreeBuffer(mQueue, mBuffers[i]);
        }else{
//            log4cplus_info("aac", "stop AudioQueue failed.");
        }
        
        AudioQueueDispose(mQueue, true);
        AudioFileClose(mRecordFile);
        mQueue = NULL;
    }
    
    g_avtimfdiff = 0;
    
}

-(BOOL)isRunning
{
    return isRunning;
}

-(void)stopVoiceDemo
{
    [self copyEncoderCookieToFile];
    AudioFileClose(mRecordFile);
    mNeedsVoiceDemo = NO;
    mRecordPacket   = 0;
    NSLog(@"%s,%@",__FUNCTION__,mRecordFilePath);
}

-(void)startVoiceDemo
{
    NSArray *searchPaths    = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath  = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:@kXDXAnyWhereVoiceDemoPathComponent];
    OSStatus status;
    
    // Get the full path to our file.
    NSString *fullFileName  = [NSString stringWithFormat:@"%@.%@",[[XDXDateTool shareXDXDateTool] getDateWithFormat_yyyy_MM_dd_HH_mm_ss],@"caf"];
    
    NSString *filePath      = [documentPath stringByAppendingPathComponent:fullFileName];
    [mRecordFilePath release];
    mRecordFilePath         = [filePath copy];;
    CFURLRef url            = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)filePath, NULL);
    
    // create the audio file
    status                  = AudioFileCreateWithURL(url, kAudioFileMPEG4Type, &_targetDes, kAudioFileFlags_EraseFile, &mRecordFile);
    CFRelease(url);
    
    // add magic cookie contain header file info for VBR data
    [self copyEncoderCookieToFile];
    
    mNeedsVoiceDemo         = YES;
    NSLog(@"%s",__FUNCTION__);
}

// demon add
-(void)startRecorder {
    
    if (isRunning) {
//        log4cplus_info("pcm", "Start recorder repeat");
        return;
    }
    
//    log4cplus_info("pcm", "starup PCM audio encoder");
    
    [self setUpRecoderWithFormatID:kAudioFormatLinearPCM];
    
    OSStatus status          = 0;
    int      bufferByteSize  = 0;
    UInt32   size            = sizeof(dataFormat);
    
    // 编码器转码设置
    [self convertBasicSetting];
    
    status =  AudioQueueNewInput(&dataFormat, inputBufferHandler, (__bridge void *)(self), NULL, NULL, 0, &mQueue);
//    log4cplus_info("pcm","AudioQueueNewInput status:%d",(int)status);
    
    status = AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription, &dataFormat, &size);
//    log4cplus_info("pcm","AudioQueueNewInput status:%u",(unsigned int)dataFormat.mFormatID);
    
    [self copyEncoderCookieToFile];
    
    //    可以计算获得，在这里使用的是固定大小
    //    bufferByteSize = [self computeRecordBufferSizeFrom:&dataFormat andDuration:kBufferDurationSeconds];
    
//    log4cplus_info("pcm","pcm raw data buff number:%d, channel number:%u",
//                   kNumberQueueBuffers,
//                   dataFormat.mChannelsPerFrame);
    
    for (int i = 0; i != kNumberQueueBuffers; i++) {
        status = AudioQueueAllocateBuffer(mQueue, 1024*2*dataFormat.mChannelsPerFrame, &mBuffers[i]);
        status = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }
    
    isRunning  = YES;
    hostTime   = 0;
    
    status     =  AudioQueueStart(mQueue, NULL);
//    log4cplus_info("pcm","AudioQueueStart status:%d",(int)status);
}


@end
