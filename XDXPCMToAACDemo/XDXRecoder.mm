//
//  XDXRecoder.m
//  XDXPCMToAACDemo
//
//  Created by 小东邪 on 23/03/2017.
//
//

/*******************************************************************************************/

    //  For detailed analysis, please refer to the blog(详细解析请参考博客)：https://chengyangli.github.io
    //  简书:http://www.jianshu.com/p/e2d072b9e4d8

    // 注意 ：1.本例中分别使用AudioQueue与AudioUnit实现PCM转换AAC进行录音，根据需要设置类变量releaseMethod并调用对应start,stop方法即可。 2.本例中Log信息均用Log4cplus插件，如果安装可以打开注释，如果未安装可以将注释中内容替换成printf();


//    Recommended to install log4cplus for print important info 
/*******************************************************************************************/

#import "XDXRecoder.h"
#import <unistd.h>
#import <mach/mach_time.h>
#import <CoreMedia/CMSync.h>
#import "XDXDateTool.h"
#import <AudioToolbox/AudioToolbox.h>

float   g_avtimfdiff = 0;
Float64 g_vstarttime = 0.0;
#define kXDXAnyWhereVoiceDemoPathComponent  "VoiceDemo"
#define kBufferDurationSeconds              .5
#define kXDXRecoderAudioBytesPerPacket      2
#define kXDXRecoderAACFramesPerPacket       1024
#define kXDXRecoderPCMTotalPacket           512
#define kXDXRecoderPCMFramesPerPacket       1
#define kXDXRecoderConverterEncodeBitRate   64000
#define kXDXAudioSampleRate                 48000.0
#define kTVURecoderPCMMaxBuffSize           2048

// Audio Unit Set Property
#define INPUT_BUS  1      ///< A I/O unit's bus 1 connects to input hardware (microphone).
#define OUTPUT_BUS 0      ///< A I/O unit's bus 0 connects to output hardware (speaker).

//voice memos Macro
#ifdef __XDX_VICE_FEATURE__
#include "XDXCommonDef.h"
#define kAudioStoreFileExtend "caf"
#endif

//XDXVOIPMessageQueue collectPcmQueue;

AudioConverterRef               _encodeConvertRef = NULL;   ///< convert param
AudioStreamBasicDescription     _targetDes;                 ///< destination format

AudioBufferList* convertPCMToAAC (XDXRecorder *recoder);

static int          pcm_buffer_size = 0;
static uint8_t      pcm_buffer[kTVURecoderPCMMaxBuffSize*2];

static int          catchCount = 0;
static float        firstTime  = 0;

#pragma mark ---------------------------------- CallBack : collect pcm and  convert  -------------------------------------
OSStatus encodeConverterComplexInputDataProc(AudioConverterRef              inAudioConverter,
                                             UInt32                         *ioNumberDataPackets,
                                             AudioBufferList                *ioData,
                                             AudioStreamPacketDescription   **outDataPacketDescription,
                                             void                           *inUserData) {
    
    ioData->mBuffers[0].mData           = inUserData;
    ioData->mBuffers[0].mNumberChannels = _targetDes.mChannelsPerFrame;
    ioData->mBuffers[0].mDataByteSize   = kXDXRecoderAACFramesPerPacket * kXDXRecoderAudioBytesPerPacket * _targetDes.mChannelsPerFrame;
    
    return 0;
}

// PCM -> AAC
AudioBufferList* convertPCMToAAC (XDXRecorder *recoder) {
    
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
    bufferList->mBuffers[0].mDataByteSize   = kTVURecoderPCMMaxBuffSize;
    
    AudioStreamPacketDescription outputPacketDescriptions;
    
    // inNumPackets设置为1表示编码产生1帧数据即返回，官方：On entry, the capacity of outOutputData expressed in packets in the converter's output format. On exit, the number of packets of converted data that were written to outOutputData. 在输入表示输出数据的最大容纳能力 在转换器的输出格式上，在转换完成时表示多少个包被写入
    UInt32 inNumPackets = 1;
    // inNumPackets设置为1表示编码产生1024帧数据即返回
    // Notice : Here, due to encoder characteristics, 1024 frames of data must be given to the encoder in order to complete a conversion, 在此处由于编码器特性,必须给编码器1024帧数据才能完成一次转换,也就是刚刚在采集数据回调中存储的pcm_buffer
    status = AudioConverterFillComplexBuffer(_encodeConvertRef,
                                             encodeConverterComplexInputDataProc,
                                             pcm_buffer,
                                             &inNumPackets,
                                             bufferList,
                                             &outputPacketDescriptions);

    if(status != noErr){
//        log4cplus_debug("Audio Recoder","set AudioConverterFillComplexBuffer status:%d inNumPackets:%d \n",(int)status, inNumPackets);
        free(bufferList->mBuffers[0].mData);
        free(bufferList);
        return NULL;
    }
    
    if (recoder.needsVoiceDemo) {
        // if inNumPackets set not correct, file will not normally play. 将转换器转换出来的包写入文件中，inNumPackets表示写入文件的起始位置
        OSStatus status = AudioFileWritePackets(recoder.mRecordFile,
                                                FALSE,
                                                bufferList->mBuffers[0].mDataByteSize,
                                                &outputPacketDescriptions,
                                                recoder.mRecordPacket,
                                                &inNumPackets,
                                                bufferList->mBuffers[0].mData);
        //        log4cplus_info("write file","write file status = %d",(int)status);
        if (status == noErr) {
            recoder.mRecordPacket += inNumPackets;  // 用于记录起始位置
        }
    }
    
    return bufferList;
}

#pragma mark - AudioUnit
static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData) {
/*
      注意：如果采集的数据是PCM需要将dataFormat.mFramesPerPacket设置为1，而本例中最终要的数据为AAC,因为本例中使用的转换器只有每次传入1024帧才能开始工作,所以在AAC格式下需要将mFramesPerPacket设置为1024.也就是采集到的inNumPackets为1，在转换器中传入的inNumPackets应该为AAC格式下默认的1，在此后写入文件中也应该传的是转换好的inNumPackets,如果有特殊需求需要将采集的数据量小于1024,那么需要将每次捕捉到的数据先预先存储在一个buffer中,等到攒够1024帧再进行转换。
 */
    
    XDXRecorder *recorder = (XDXRecorder *)inRefCon;
    
    // 将回调数据传给_buffList
    AudioUnitRender(recorder->_audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, recorder->_buffList);
    
    void    *bufferData = recorder->_buffList->mBuffers[0].mData;
    UInt32   bufferSize = recorder->_buffList->mBuffers[0].mDataByteSize;
    //    printf("Audio Recoder Render dataSize : %d \n",bufferSize);
    
    // 由于PCM转成AAC的转换器每次需要有1024个采样点（每一帧2个字节）才能完成一次转换，所以每次需要2048大小的数据，这里定义的pcm_buffer用来累加每次存储的bufferData
    memcpy(pcm_buffer+pcm_buffer_size, bufferData, bufferSize);
    pcm_buffer_size = pcm_buffer_size + bufferSize;
    
    if(pcm_buffer_size >= kTVURecoderPCMMaxBuffSize) {
        AudioBufferList *bufferList = convertPCMToAAC(recorder);
        
        // 因为采样不可能每次都精准的采集到1024个样点，所以如果大于2048大小就先填满2048，剩下的跟着下一次采集一起送给转换器
        memcpy(pcm_buffer, pcm_buffer + kTVURecoderPCMMaxBuffSize, pcm_buffer_size - kTVURecoderPCMMaxBuffSize);
        pcm_buffer_size = pcm_buffer_size - kTVURecoderPCMMaxBuffSize;
        
        // free memory
        if(bufferList) {
            free(bufferList->mBuffers[0].mData);
            free(bufferList);
        }
    }
    return noErr;
}

#pragma mark - AudioQueue
static void inputBufferHandler(void *                                 inUserData,
                               AudioQueueRef                          inAQ,
                               AudioQueueBufferRef                    inBuffer,
                               const AudioTimeStamp *                 inStartTime,
                               UInt32                                 inNumPackets,
                               const AudioStreamPacketDescription*	  inPacketDesc) {
    XDXRecorder *recoder        = (__bridge XDXRecorder *)inUserData;
    
    /*
     inNumPackets 总包数：音频队列缓冲区大小 （在先前估算缓存区大小为kXDXRecoderAACFramesPerPacket*2）/ （dataFormat.mFramesPerPacket (采集数据每个包中有多少帧，此处在初始化设置中为1) * dataFormat.mBytesPerFrame（每一帧中有多少个字节，此处在初始化设置中为每一帧中两个字节）），所以可以根据该公式计算捕捉PCM数据时inNumPackets。
     注意：如果采集的数据是PCM需要将dataFormat.mFramesPerPacket设置为1，而本例中最终要的数据为AAC,因为本例中使用的转换器只有每次传入1024帧才能开始工作,所以在AAC格式下需要将mFramesPerPacket设置为1024.也就是采集到的inNumPackets为1，在转换器中传入的inNumPackets应该为AAC格式下默认的1，在此后写入文件中也应该传的是转换好的inNumPackets,如果有特殊需求需要将采集的数据量小于1024,那么需要将每次捕捉到的数据先预先存储在一个buffer中,等到攒够1024帧再进行转换。
     */
    
    // collect pcm data，可以在此存储
    
    // 由于PCM转成AAC的转换器每次需要有1024个采样点（每一帧2个字节）才能完成一次转换，所以每次需要2048大小的数据，这里定义的pcm_buffer用来累加每次存储的bufferData
    memcpy(pcm_buffer+pcm_buffer_size, inBuffer->mAudioData, inBuffer->mAudioDataByteSize);
    pcm_buffer_size = pcm_buffer_size + inBuffer->mAudioDataByteSize;
    
    if(pcm_buffer_size >= kTVURecoderPCMMaxBuffSize){
        AudioBufferList *bufferList = convertPCMToAAC(recoder);
        
        // 因为采样不可能每次都精准的采集到1024个样点，所以如果大于2048大小就先填满2048，剩下的跟着下一次采集一起送给转换器
        memcpy(pcm_buffer, pcm_buffer + kTVURecoderPCMMaxBuffSize, pcm_buffer_size - kTVURecoderPCMMaxBuffSize);
        pcm_buffer_size = pcm_buffer_size - kTVURecoderPCMMaxBuffSize;
        
        // free memory
        if(bufferList) {
            free(bufferList->mBuffers[0].mData);
            free(bufferList);
        }
    }
    // 出队
    AudioQueueRef queue = recoder.mQueue;
    if (recoder.isRunning) {
        AudioQueueEnqueueBuffer(queue, inBuffer, 0, NULL);
    }
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
-(void)copyEncoderCookieToFile {
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


-(void)setUpRecoderWithFormatID:(UInt32)formatID {
    // Notice : The settings here are official recommended settings,can be changed according to specific requirements. 此处的设置为官方推荐设置,可根据具体需求修改部分设置
    //setup auido sample rate, channel number, and format ID
    memset(&dataFormat, 0, sizeof(dataFormat));
    
    UInt32 size = sizeof(dataFormat.mSampleRate);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                            &size,
                            &dataFormat.mSampleRate);
    dataFormat.mSampleRate = kXDXAudioSampleRate;
    
    size = sizeof(dataFormat.mChannelsPerFrame);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels,
                            &size,
                            &dataFormat.mChannelsPerFrame);
    dataFormat.mFormatID = formatID;
    dataFormat.mChannelsPerFrame = 1;
    
    if (formatID == kAudioFormatLinearPCM) {
        if (self.releaseMethod == XDXRecorderReleaseMethodAudioQueue) {
            dataFormat.mFormatFlags     = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        }else if (self.releaseMethod == XDXRecorderReleaseMethodAudioQueue) {
            dataFormat.mFormatFlags     = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        }
        
        dataFormat.mBitsPerChannel  = 16;
        dataFormat.mBytesPerPacket  = dataFormat.mBytesPerFrame = (dataFormat.mBitsPerChannel / 8) * dataFormat.mChannelsPerFrame;
        dataFormat.mFramesPerPacket = kXDXRecoderPCMFramesPerPacket; // 用AudioQueue采集pcm需要这么设置
    }
}

-(int)computeRecordBufferSizeFrom:(const AudioStreamBasicDescription *) format andDuration:(float) seconds {
    int packets = 0;
    int frames  = 0;
    int bytes   = 0;
    
    frames = (int)ceil(seconds * format->mSampleRate);
    
    if (format->mBytesPerFrame > 0) {
        bytes = frames * format->mBytesPerFrame;
    }else {
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
        
        if (format->mFramesPerPacket > 0) {
            packets = frames / format->mFramesPerPacket;
        }else{
            packets = frames;	// worst-case scenario: 1 frame in a packet
        }
        
        if (packets == 0) packets = 1;		// sanity check
        bytes = packets * maxPacketSize;
    }
    
    return bytes;
}

// Transcoder basic information settings,转码器基本信息设置
- (NSString *)convertBasicSetting {
    // 此处目标格式其他参数均为默认，系统会自动计算，否则无法进入encodeConverterComplexInputDataProc回调
    AudioStreamBasicDescription sourceDes = dataFormat;
    AudioStreamBasicDescription targetDes;
    
    memset(&targetDes, 0, sizeof(targetDes));
    targetDes.mFormatID                   = kAudioFormatMPEG4AAC;
    targetDes.mSampleRate                 = kXDXAudioSampleRate;
    targetDes.mChannelsPerFrame           = dataFormat.mChannelsPerFrame;
    targetDes.mFramesPerPacket            = kXDXRecoderAACFramesPerPacket;
    
    OSStatus status     = 0;
    UInt32 targetSize   = sizeof(targetDes);
    status              = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &targetSize, &targetDes);
    //    log4cplus_info("pcm", "create target data format status:%d",(int)status);
    
    memset(&_targetDes, 0, sizeof(_targetDes));
    memcpy(&_targetDes, &targetDes, targetSize);
    
    // select software coding,选择软件编码
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
    
    if (_encodeConvertRef == NULL) {
        status          = AudioConverterNewSpecific(&sourceDes, &targetDes, 1,
                                                    &audioClassDes, &_encodeConvertRef);
        
        if (status != noErr) {
//            log4cplus_info("Audio Recoder","new convertRef failed status:%d \n",(int)status);
            return @"Error : New convertRef failed \n";
        }
    }
    
    targetSize      = sizeof(sourceDes);
    status          = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentInputStreamDescription, &targetSize, &sourceDes);
    //    log4cplus_info("pcm","get sourceDes status:%d",(int)status);
    
    targetSize      = sizeof(targetDes);
    status          = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentOutputStreamDescription, &targetSize, &targetDes);
    //    log4cplus_info("pcm","get targetDes status:%d",(int)status);
    
    // 设置码率，需要和采样率对应
    UInt32 bitRate  = kXDXRecoderConverterEncodeBitRate;
    targetSize      = sizeof(bitRate);
    status          = AudioConverterSetProperty(_encodeConvertRef,
                                                kAudioConverterEncodeBitRate,
                                                targetSize, &bitRate);
    //    log4cplus_info("pcm","set covert property bit rate status:%d",(int)status);
    if (status != noErr) {
//        log4cplus_info("Audio Recoder","set covert property bit rate status:%d",(int)status);
        return @"Error : Set covert property bit rate failed";
    }
    
    return nil;
}

#pragma mark public
#pragma mark--------------------------------------------------------------------------------------------------------

-(id)init {
    if (self = [super init]) {
        isRunning = NO;
        
        NSArray *searchPaths        = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *ituneShareDir     = searchPaths[0];
        NSString *documentPath      = [ituneShareDir stringByAppendingPathComponent:@kXDXAnyWhereVoiceDemoPathComponent];
        
        NSFileManager *fileManager  = [NSFileManager defaultManager];
        NSError *error              = nil;
        
        if ([fileManager fileExistsAtPath:documentPath] == NO) {
            [fileManager createDirectoryAtPath:documentPath withIntermediateDirectories:NO attributes:nil error:&error];
        }
        
        mNeedsVoiceDemo = NO;
        
        if (self.releaseMethod == XDXRecorderReleaseMethodAudioUnit) {
            // Init Audio Unit and Convert Basic Setting
            [self initAudioComponent];
            [self initBuffer];
            [self setAudioUnitPropertyAndFormat];
            [self convertBasicSetting];
            [self initRecordeCallback];
            [self copyEncoderCookieToFile];
            // Calls to AudioUnitInitialize() can fail if called back-to-back on different ADM instances. A fall-back solution is to allow multiple sequential calls with as small delay between each. This factor sets the max number of allowed initialization attempts.
            OSStatus status = AudioUnitInitialize(_audioUnit);
            if (status != noErr) {
//                log4cplus_info("Audio Recoder", "couldn't initialize AURemoteIO instance, status : %d \n",status);
            }
        }
        
    }
    
    return self;
}

-(BOOL)isRunning {
    return isRunning;
}

-(void)stopVoiceDemo {
    [self copyEncoderCookieToFile];
    AudioFileClose(mRecordFile);
    mNeedsVoiceDemo = NO;
    mRecordPacket   = 0;
    NSLog(@"%s,%@",__FUNCTION__,mRecordFilePath);
}

-(void)startVoiceDemo {
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

#pragma mark - Audio Queue
-(void)startAudioQueueRecorder {
    // Reset pcm_buffer to save convert handle
    memset(pcm_buffer, 0, pcm_buffer_size);
    pcm_buffer_size = 0;
    
    if (isRunning) {
//        log4cplus_info("pcm", "Start recorder repeat");
        return;
    }
    
//    log4cplus_info("pcm", "starup PCM audio encoder");
    
    [self setUpRecoderWithFormatID:kAudioFormatLinearPCM];
    
    OSStatus status          = 0;
    UInt32   size            = sizeof(dataFormat);
    
    // 编码器转码设置
    NSString *err = [self convertBasicSetting];
    if (err != nil) {
        NSString *error = nil;
        for (int i = 0; i < 3; i++) {
            usleep(100*1000);
            error = [self convertBasicSetting];
            if (error == nil) break;
        }
        // if init this class failed then restart three times , if failed again,can handle at there
//        [self exitWithErr:error];
    }
    
    status =  AudioQueueNewInput(&dataFormat, inputBufferHandler, (__bridge void *)(self), NULL, NULL, 0, &mQueue);
//    log4cplus_info("pcm","AudioQueueNewInput status:%d",(int)status);
    if (status != noErr) {
//        log4cplus_error("Audio Recoder","AudioQueueNewInput Failed status:%d",(int)status);
    }
    
    status = AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription, &dataFormat, &size);
//    log4cplus_info("pcm","AudioQueueNewInput status:%u",(unsigned int)dataFormat.mFormatID);
    
    [self copyEncoderCookieToFile];
    
    //    可以计算获得，在这里使用的是固定大小
    //    bufferByteSize = [self computeRecordBufferSizeFrom:&dataFormat andDuration:kBufferDurationSeconds];
    
//    log4cplus_info("pcm","pcm raw data buff number:%d, channel number:%u",
//                   kNumberQueueBuffers,
//                   dataFormat.mChannelsPerFrame);
    
    for (int i = 0; i != kNumberQueueBuffers; i++) {
        status = AudioQueueAllocateBuffer(mQueue, kXDXRecoderPCMTotalPacket*kXDXRecoderAudioBytesPerPacket*dataFormat.mChannelsPerFrame, &mBuffers[i]);
        status = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }
    
    isRunning  = YES;
    hostTime   = 0;
    
    status     =  AudioQueueStart(mQueue, NULL);
//    log4cplus_info("pcm","AudioQueueStart status:%d",(int)status);
}

-(void)stopAudioQueueRecorder {
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
    
    if(_encodeConvertRef != NULL) {
        //        log4cplus_info("Audio Recoder", "release _encodeConvertRef.");
        AudioConverterDispose(_encodeConvertRef);
        _encodeConvertRef = NULL;
    }
    
    g_avtimfdiff = 0;
    
}

#pragma mark - AudioUnit
- (void)startAudioUnitRecorder {
    OSStatus status;
    
    if (isRunning) {
//        log4cplus_info("Audio Recoder", "Start recorder repeat \n");
        return;
    }
    
    [self initGlobalVar];
    
//    log4cplus_info("Audio Recoder", "starup PCM audio encoder \n");
    
    status = AudioOutputUnitStart(_audioUnit);
//    log4cplus_info("Audio Recoder", "AudioOutputUnitStart status : %d \n",status);
    if (status == noErr) {
        isRunning  = YES;
        hostTime   = 0;
    }
}

-(void)stopAudioUnitRecorder {
    if (isRunning == NO) {
//        log4cplus_info("Audio Recoder", "Stop recorder repeat \n");
        return;
    }
    
//    log4cplus_info("Audio Recoder","stop pcm encoder \n");
    
    isRunning = NO;
    
    [self copyEncoderCookieToFile];
    OSStatus status = AudioOutputUnitStop(_audioUnit);
    if (status != noErr){
//        log4cplus_info("Audio Recoder", "stop AudioUnit failed. \n");
    }
    
    AudioFileClose(mRecordFile);
    g_avtimfdiff = 0;
}

- (void)initGlobalVar {
    // 初始化pcm_buffer，pcm_buffer是存储每次捕获的PCM数据，因为PCM若要转成AAC需要攒够2048个字节给转换器才能完成一次转换，Reset pcm_buffer to save convert handle
    memset(pcm_buffer, 0, pcm_buffer_size);
    pcm_buffer_size = 0;
}

- (void)initBuffer {
    // 禁用AudioUnit默认的buffer而使用我们自己写的全局BUFFER,用来接收每次采集的PCM数据，Disable AU buffer allocation for the recorder, we allocate our own.
    UInt32 flag     = 0;
    OSStatus status = AudioUnitSetProperty(_audioUnit,
                                           kAudioUnitProperty_ShouldAllocateBuffer,
                                           kAudioUnitScope_Output,
                                           INPUT_BUS,
                                           &flag,
                                           sizeof(flag));
    if (status != noErr) {
//        log4cplus_info("Audio Recoder", "couldn't AllocateBuffer of AudioUnitCallBack, status : %d \n",status);
    }
    _buffList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    _buffList->mNumberBuffers               = 1;
    _buffList->mBuffers[0].mNumberChannels  = dataFormat.mChannelsPerFrame;
    _buffList->mBuffers[0].mDataByteSize    = kTVURecoderPCMMaxBuffSize * sizeof(short);
    _buffList->mBuffers[0].mData            = (short *)malloc(sizeof(short) * kTVURecoderPCMMaxBuffSize);
}

- (void)initAudioComponent {
    OSStatus status;
    // 配置AudioUnit基本信息
    AudioComponentDescription audioDesc;
    audioDesc.componentType         = kAudioUnitType_Output;
    // 如果你的应用程序需要去除回声将componentSubType设置为kAudioUnitSubType_VoiceProcessingIO，否则根据需求设置为其他，在博客中有介绍
    audioDesc.componentSubType      = kAudioUnitSubType_VoiceProcessingIO;//kAudioUnitSubType_VoiceProcessingIO;
    // 苹果自己的标志
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags        = 0;
    audioDesc.componentFlagsMask    = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    // 新建一个AudioComponent对象，只有这步完成才能进行后续步骤，所以顺序不可颠倒
    status = AudioComponentInstanceNew(inputComponent, &_audioUnit);
    if (status != noErr)  {
        _audioUnit = NULL;
//        log4cplus_info("Audio Recoder", "couldn't create a new instance of AURemoteIO, status : %d \n",status);
    }
}

// 因为本例只做录音功能，未实现播放功能，所以没有设置播放相关设置。
- (void)setAudioUnitPropertyAndFormat {
    OSStatus status;
    [self setUpRecoderWithFormatID:kAudioFormatLinearPCM];
    
    // 应用audioUnit设置的格式
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  INPUT_BUS,
                                  &dataFormat,
                                  sizeof(dataFormat));
    if (status != noErr) {
//        log4cplus_info("Audio Recoder", "couldn't set the input client format on AURemoteIO, status : %d \n",status);
    }
    // 去除回声开关
    UInt32 echoCancellation;
    AudioUnitSetProperty(_audioUnit,
                         kAUVoiceIOProperty_BypassVoiceProcessing,
                         kAudioUnitScope_Global,
                         0,
                         &echoCancellation,
                         sizeof(echoCancellation));
    
    // AudioUnit输入端默认是关闭，需要将他打开
    UInt32 flag = 1;
    status      = AudioUnitSetProperty(_audioUnit,
                                       kAudioOutputUnitProperty_EnableIO,
                                       kAudioUnitScope_Input,
                                       INPUT_BUS,
                                       &flag,
                                       sizeof(flag));
    if (status != noErr) {
//        log4cplus_info("Audio Recoder", "could not enable input on AURemoteIO, status : %d \n",status);
    }
}

- (void)initRecordeCallback {
    // 设置回调，有两种方式，一种是采集pcm的BUFFER使用系统回调中的参数，另一种是使用我们自己的，本例中使用的是自己的，所以回调中的ioData为空。如果想要使用回调中的请看博客另一种设置方法。
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc        = RecordCallback;
    recordCallback.inputProcRefCon  = (__bridge void *)self;
    OSStatus status                 = AudioUnitSetProperty(_audioUnit,
                                                           kAudioOutputUnitProperty_SetInputCallback,
                                                           kAudioUnitScope_Global,
                                                           INPUT_BUS,
                                                           &recordCallback,
                                                           sizeof(recordCallback));
    
    if (status != noErr) {
//        log4cplus_info("Audio Recoder", "Audio Unit set record Callback failed, status : %d \n",status);
    }
}

- (void)dealloc {
//    OSStatus status = AudioUnitUninitialize(_audioUnit);
//    if (status != noErr) log4cplus_info("Audio Recoder", "AudioUnitUninitialize failed, status : %d \n",status);

    OSStatus result = AudioComponentInstanceDispose(_audioUnit);
    if (result != noErr) {
//        log4cplus_info("Audio Recoder", "AudioComponentInstanceDispose failed. status : %d \n",result);
    }

    _audioUnit = NULL;

    if(_buffList) {
        free(_buffList->mBuffers[0].mData);
        free(_buffList);
    }
    [super dealloc];
    
}

@end
