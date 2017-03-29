
### 本例需求：将Mic采集的PCM转成AAC，可得到两种不同数据,本例采用AudioQueue存储
### 原理：由于需求更改为Mic采集的pcm一路提供给WebRTC使用，另一路将pcm转为aac，将aac提供给直播用的API。因此应该先让Mic采集原始pcm数据，采用队列保存，然后在回调函数中将其转换为aac提供给C++API

![Alt text](/img/1.png)

### 源代码地址:[PCM->AAC](https://github.com/ChengyangLi/XDXPCMToAACDemo)
### 博客地址:[PCM->AAC](https://chengyangli.github.io/2017/03/24/record)

## 一.本文需要基本知识点

### C语言相关函数：
1.memset：
原型： void	*memset(void *__b, int __c, size_t __len);
解释：将s中当前位置后面的n个字节(typedef unsigned int size_t) 用ch替换并返回s
作用：在一段内存块中填充某个特定的值，它是对较大的结构体或数组进行清零操作的一种最快方法。

2.memcpy：
原型： void *memcpy(void *dest, const void *src, size_t n); 
解释：从源src所指的内存地址的起始位置开始拷贝n个字节到目标dest所指的内存地址的起始位置中


### OC 中部分知识点：
1.OSStaus:状态码，如果没有错误返回0：（即noErr）

2.AudioFormatGetPropertyInfo：

```
原型： 
AudioFormatGetPropertyInfo(
					    	AudioFormatPropertyID   inPropertyID,
							UInt32                  inSpecifierSize,
		 					const void * __nullable inSpecifier,
							UInt32 *                outPropertyDataSize);
									
* 作用：检索给定属性的信息，比如编码器目标格式的size等

```

3.AudioSessionGetProperty：

```
原型： 
extern OSStatus
AudioSessionGetProperty(    
							 	AudioSessionPropertyID     inID,
		            			UInt32                     *ioDataSize,
								void                       *outData);
									
* 作用：获取指定AudioSession对象的inID属性的值（比如采样率，声道数等等）
```

### 音频基础知识
1. AVFoundation框架中的AVAudioPlayer和AVAudioRecorder类，用法简单，但是不支持流式，也就意味着在播放音频前，必须等到整个音频加载完成后，才能开始播放音频；录音时，也必须等到录音结束后才能获得录音数据。

2. 在iOS和Mac OS X中，音频队列Audio Queues是一个用来录制和播放音频的软件对象，也就是说，可以用来录音和播放，录音能够获取实时的PCM原始音频数据。

3. 数据介绍
                                                           
（1）In CBR (constant bit rate) formats, such as linear PCM and IMA/ADPCM, all packets are the same size.
                                                                                   
（2）In VBR (variable bit rate) formats, such as AAC, Apple Lossless, and MP3, all packets have the same number of frames but the number of bits in each sample value can vary.

（3）In VFR (variable frame rate) formats, packets have a varying number of frames. There are no commonly used formats of this type.

4. 概念：

(1)音频文件的组成：文件格式（或者音频容器）+数据格式（或者音频编码）

>知识点：

- 文件格式是用于形容文件本身的格式，可以通过多种不同方法为真正的音频数据编码，例如CAF文件便是一种文件格式，它能够包含MP3格式，线性PCM以及其他数据格式音频
线性PCM:这是表示线性脉冲编码机制，主要是描写用于将模拟声音数据转换成数组格式的技术，简单地说也就是未压缩的数据。因为数据是未压缩的，所以我们便可以最快速地播放出音频，而如果空间不是问题的话这便是iPhone 音频的优先代码选择	  

(2).音频文件计算大小
简述：声卡对声音的处理质量可以用三个基本参数来衡量，即采样频率，采样位数和声道数。
>知识点：

- 采样频率：单位时间内采样次数。采样频率越大，采样点之间的间隔就越小，数字化后得到的声音就越逼真，但相应的数据量就越大，声卡一般提供11.025kHz,22.05kHz和44.1kHz等不同的采样频率。

- 采样位数：记录每次采样值数值大小的位数。采样位数通常有8bits或16bits两种，采样位数越大，所能记录的声音变化度就越细腻，相应的数据量就越大。

- 声道数：处理的声音是单声道还是立体声。单声道在声音处理过程中只有单数据流，而立体声则需要左右声道的两个数据流。显然，立体声的效果要好，但相应数据量要比单声道数据量加倍。

- 声音数据量的计算公式：数据量（字节 / 秒）=（采样频率（Hz）* 采样位数（bit）* 声道数）/  8
单声道的声道数为1，立体声的声道数为2. 字节B，1MB=1024KB = 1024*1024B

(3).音频队列 — 详细请参考 [Audio Queue](http://blog.csdn.net/jiangyiaxiu/article/details/9190035)

### 简述：在iOS和Mac OS X中，音频队列是一个用来录制和播放音频的软件对象，他用AudioQueueRef这个不透明数据类型来表示，该类型在AudioQueue.h头文件中声明。

### 工作：
- 连接音频硬件
- 内存管理
- 根据需要为已压缩的音频格式引入编码器
- 媒体的录制或播放

> 你可以将音频队列配合其他Core Audio的接口使用，再加上相对少量的自定义代码就可以在你的应用程序中创建一套完整的数字音频录制或播放解决方案。

### 结构：

- 一组音频队列缓冲区(audio queue buffers)，每个音频队列缓冲区都是一个存储音频数据的临时仓库

- 一个缓冲区队列(buffer queue)，一个包含音频队列缓冲区的有序列表

- 一个你自己编写的音频队列回调函数(audio queue callback)

#### 它的架构很大程度上依赖于这个音频队列是用来录制还是用来播放的。不同之处在于音频队列如何连接到它的输入和输入，还有它的回调函数所扮演的角色。



## 二.主要方法解析

### 调用步骤，首先将项目设置为MRC,在控制器中配置audioSession基本设置(基本设置，不会谷歌)，导入该头文件，直接在需要时机调用该类startRecord与stopRecord方法，另外还提供了生成录音文件的功能，具体参考github中的代码。

### 1.设置AudioStreamBasicDescription 基本信息
```
-(void)startRecorderTest {
    // save collect pcm data, 下面一行是本人采用单独设计的队列，大家可以自己定义一个队列存取
    // XDXSignaling::getInstance()->InitQueue(&collectPcmQueue);
    // 用特定队列存取pcm的值，在这里初始化，可以采用不同方式进行存储，也可以自己定义一个队列，具体实现不做解释
    
// 是否正在录制
    if (isRunning) {
        // log4cplus_info("pcm", "Start recorder repeat");
        return;
    }
    
// 本例中采用log4打印log信息，若你没有可以不用，删除有关Log4的语句
    // log4cplus_info("pcm", "starup PCM audio encoder");
    
// 设置采集的数据的类型为PCM
    [self setUpRecoderWithFormatID:kAudioFormatLinearPCM];
    

    OSStatus status          = 0;
    UInt32   size            = sizeof(dataFormat);
    
    // 编码器转码设置
    [self convertBasicSetting];
    
    // 新建一个队列,第二个参数注册回调函数，第三个防止内存泄露
    status =  AudioQueueNewInput(&dataFormat, inputBufferHandler, (__bridge void *)(self), NULL, NULL, 0, &mQueue);
    // log4cplus_info("pcm","AudioQueueNewInput status:%d",(int)status);
    
// 获取队列属性
    status = AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription, &dataFormat, &size);
    // log4cplus_info("pcm","AudioQueueNewInput status:%u",(unsigned int)dataFormat.mFormatID);
    
// 这里将头信息添加到写入文件中，若文件数据为CBR,不需要添加，为VBR需要添加
    [self copyEncoderCookieToFile];
    
    //    可以计算获得，在这里使用的是固定大小
    //    bufferByteSize = [self computeRecordBufferSizeFrom:&dataFormat andDuration:kBufferDurationSeconds];
    
    // log4cplus_info("pcm","pcm raw data buff number:%d, channel number:%u",
                   kNumberQueueBuffers,
                   dataFormat.mChannelsPerFrame);
    
// 设置三个音频队列缓冲区
    for (int i = 0; i != kNumberQueueBuffers; i++) {
	// 注意：为每个缓冲区分配大小，由于这里将bufferSize写死所以需要和回调函数对应，否则会出错
        status = AudioQueueAllocateBuffer(mQueue, 1024*2*dataFormat.mChannelsPerFrame, &mBuffers[i]);
	// 入队
        status = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }
    
    isRunning  = YES;
    hostTime   = 0;
    
    status     =  AudioQueueStart(mQueue, NULL);
    log4cplus_info("pcm","AudioQueueStart status:%d",(int)status);
}
```

> 初始化输出流的结构体描述
 
 ```
struct AudioStreamBasicDescription
{
    Float64          	mSampleRate;	    // 采样率 ：Hz
    AudioFormatID      	mFormatID;	        // 采样数据的类型，PCM,AAC等
    AudioFormatFlags    mFormatFlags;	    // 每种格式特定的标志，无损编码 ，0表示没有
    UInt32            	mBytesPerPacket;    // 一个数据包中的字节数
    UInt32              mFramesPerPacket;   // 一个数据包中的帧数，每个packet的帧数。如果是未压缩的音频数据，值是1。动态帧率格式，这个值是一个较大的固定数字，比如说AAC的1024。如果是动态大小帧数（比如Ogg格式）设置为0。
    UInt32            	mBytesPerFrame;     // 每一帧中的字节数
    UInt32            	mChannelsPerFrame;  // 每一帧数据中的通道数，单声道为1，立体声为2
    UInt32              mBitsPerChannel;    // 每个通道中的位数，1byte = 8bit
    UInt32              mReserved; 		    // 8字节对齐，填0
};
typedef struct AudioStreamBasicDescription  AudioStreamBasicDescription;

 ```
 
注意： kNumberQueueBuffers，音频队列可以使用任意数量的缓冲区。你的应用程序制定它的数量。一般情况下这个数字是3。这样就可以让给一个忙于将数据写入磁盘，同时另一个在填充新的音频数据，第三个缓冲区在需要做磁盘I/O延迟补偿的时候可用
 

> 如何使用AudioQueue:

1. 创建输入队列AudioQueueNewInput
2. 分配buffers
3. 入队：AudioQueueEnqueueBuffer
4. 回调函数采集音频数据
5. 出队

> AudioQueueNewInput

```
// 作用：创建一个音频队列为了录制音频数据
原型：extern OSStatus             
		AudioQueueNewInput( const AudioStreamBasicDescription   *inFormat, 同上
                            AudioQueueInputCallback             inCallbackProc, // 注册回调函数
                            void * __nullable               	inUserData,		
                            CFRunLoopRef __nullable         	inCallbackRunLoop,
                            CFStringRef __nullable          	inCallbackRunLoopMode,
                            UInt32                          	inFlags,
                            AudioQueueRef __nullable        	* __nonnull outAQ)；

// 这个函数的第四个和第五个参数是有关于线程的，我设置成null，代表它默认使用内部线程去录音，而且还是异步的
```

### 2.设置采集数据的格式，采集PCM必须按照如下设置，参考苹果官方文档，不同需求自己另行修改

```
 -(void)setUpRecoderWithFormatID:(UInt32)formatID {

    //setup auido sample rate, channel number, and format ID
    memset(&dataFormat, 0, sizeof(dataFormat));
    
    UInt32 size = sizeof(dataFormat.mSampleRate);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                            &size,
                            &dataFormat.mSampleRate);
    dataFormat.mSampleRate = 44100.0;	// 设置采样率
    
    size = sizeof(dataFormat.mChannelsPerFrame);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels,
                            &size,
                            &dataFormat.mChannelsPerFrame);
    dataFormat.mFormatID = formatID;
    
    // 关于采集PCM数据是根据苹果官方文档给出的Demo设置，至于为什么这么设置可能与采集回调函数内部实现有关，修改的话请谨慎
    if (formatID == kAudioFormatLinearPCM)
    {
    	 /*
    	  为保存音频数据的方式的说明，如可以根据大端字节序或小端字节序，
    	  浮点数或整数以及不同体位去保存数据
          例如对PCM格式通常我们如下设置：kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked等
          */
        dataFormat.mFormatFlags     = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        // 每个通道里，一帧采集的bit数目
        dataFormat.mBitsPerChannel  = 16;
        // 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目
        dataFormat.mBytesPerPacket  = dataFormat.mBytesPerFrame = (dataFormat.mBitsPerChannel / 8) * dataFormat.mChannelsPerFrame;
        // 每个包中的帧数，采集PCM数据需要将dataFormat.mFramesPerPacket设置为1，否则回调不成功
        dataFormat.mFramesPerPacket = 1;
    }
}
```

### 3.将PCM转成AAC一些基本设置

```
-(void)convertBasicSetting {
    // 此处目标格式其他参数均为默认，系统会自动计算，否则无法进入encodeConverterComplexInputDataProc回调

    AudioStreamBasicDescription sourceDes = dataFormat; // 原始格式
    AudioStreamBasicDescription targetDes;              // 转码后格式
    
    // 设置目标格式及基本信息
    memset(&targetDes, 0, sizeof(targetDes));
    targetDes.mFormatID           = kAudioFormatMPEG4AAC;
    targetDes.mSampleRate         = 44100.0;
    targetDes.mChannelsPerFrame   = dataFormat.mChannelsPerFrame;
    targetDes.mFramesPerPacket    = 1024; // 采集的为AAC需要将targetDes.mFramesPerPacket设置为1024，AAC软编码需要喂给转换器1024个样点才开始编码，这与回调函数中inNumPackets有关，不可随意更改
    
    OSStatus status     = 0;
    UInt32 targetSize   = sizeof(targetDes);
    status              = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &targetSize, &targetDes);
    // log4cplus_info("pcm", "create target data format status:%d",(int)status);
	
    memset(&_targetDes, 0, sizeof(_targetDes));
    // 赋给全局变量
    memcpy(&_targetDes, &targetDes, targetSize);
    
    // 选择软件编码
    AudioClassDescription audioClassDes;
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                        sizeof(targetDes.mFormatID),
                                        &targetDes.mFormatID,
                                        &targetSize);
    // log4cplus_info("pcm","get kAudioFormatProperty_Encoders status:%d",(int)status);
    
    // 计算编码器容量
    UInt32 numEncoders = targetSize/sizeof(AudioClassDescription);
    // 用数组存放编码器内容
    AudioClassDescription audioClassArr[numEncoders];
	// 将编码器属性赋给数组
    AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                           sizeof(targetDes.mFormatID),
                           &targetDes.mFormatID,
                           &targetSize,
                           audioClassArr);
    // log4cplus_info("pcm","wrirte audioClassArr status:%d",(int)status);
    
 // 遍历数组，设置软编
    for (int i = 0; i < numEncoders; i++) {
        if (audioClassArr[i].mSubType == kAudioFormatMPEG4AAC && audioClassArr[i].mManufacturer == kAppleSoftwareAudioCodecManufacturer) {
            memcpy(&audioClassDes, &audioClassArr[i], sizeof(AudioClassDescription));
            break;
        }
    }
    
    // 新建一个编码对象，设置原，目标格式
    status          = AudioConverterNewSpecific(&sourceDes, &targetDes, 1,
                                                &audioClassDes, &_encodeConvertRef);
    // log4cplus_info("pcm","new convertRef status:%d",(int)status);
    
// 获取原始格式大小
    targetSize      = sizeof(sourceDes);
    status          = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentInputStreamDescription, &targetSize, &sourceDes);
    // log4cplus_info("pcm","get sourceDes status:%d",(int)status);
    
// 获取目标格式大小
    targetSize      = sizeof(targetDes);
    status          = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentOutputStreamDescription, &targetSize, &targetDes);;
    // log4cplus_info("pcm","get targetDes status:%d",(int)status);
    
    // 设置码率，需要和采样率对应
    UInt32 bitRate  = 64000;
    targetSize      = sizeof(bitRate);
    status          = AudioConverterSetProperty(_encodeConvertRef,
                                                kAudioConverterEncodeBitRate,
                                                targetSize, &bitRate);
    // log4cplus_info("pcm","set covert property bit rate status:%d",(int)status);
}
```

> AudioFormatGetProperty：

```
原型： 
extern OSStatus
	 
AudioFormatGetProperty(	AudioFormatPropertyID    inPropertyID,
							UInt32				        inSpecifierSize,
							const void * __nullable  inSpecifier,
							UInt32 	 * __nullable  ioPropertyDataSize,
							void * __nullabl         outPropertyData);
作用：检索某个属性的值
```

> AudioClassDescription：

指的是一个能够对一个信号或者一个数据流进行变换的设备或者程序。这里指的变换既包括将 信号或者数据流进行编码（通常是为了传输、存储或者加密）或者提取得到一个编码流的操作，也包括为了观察或者处理从这个编码流中恢复适合观察或操作的形式的操作。编解码器经常用在视频会议和流媒体等应用中。


默认情况下，Apple会创建一个硬件编码器，如果硬件不可用，会创建软件编码器。

经过我的测试，硬件AAC编码器的编码时延很高，需要buffer大约2秒的数据才会开始编码。而软件编码器的编码时延就是正常的，只要喂给1024个样点，就会开始编码。

```
AudioConverterNewSpecific：
原型： extern OSStatus
AudioConverterNewSpecific(  const AudioStreamBasicDescription * inSourceFormat,
                            const AudioStreamBasicDescription * inDestinationFormat,
                            UInt32                              inNumberClassDescriptions,
                            const AudioClassDescription *       inClassDescriptions,
                            AudioConverterRef __nullable * __nonnull outAudioConverter)；
      
解释：创建一个转换器
作用：设置一些转码基本信息          
```

```
AudioConverterSetProperty：
原型：extern OSStatus 
AudioConverterSetProperty(  AudioConverterRef           inAudioConverter,
                            AudioConverterPropertyID    inPropertyID,
                            UInt32                      inPropertyDataSize,
                            const void *                inPropertyData)；
作用：设置码率，需要注意，AAC并不是随便的码率都可以支持。比如如果PCM采样率是44100KHz，那么码率可以设置64000bps，如果是16K，可以设置为32000bps。
```

### 4.设置最终音频文件的头部信息(此类写法为将pcm转为AAC的写法)

```
-(void)copyEncoderCookieToFile
{
    // Grab the cookie from the converter and write it to the destination file.
    UInt32 cookieSize = 0;
    OSStatus error = AudioConverterGetPropertyInfo(_encodeConvertRef, kAudioConverterCompressionMagicCookie, &cookieSize, NULL);
    
    // If there is an error here, then the format doesn't have a cookie - this is perfectly fine as som formats do not.
    // log4cplus_info("cookie","cookie status:%d %d",(int)error, cookieSize);
    if (error == noErr && cookieSize != 0) {
        char *cookie = (char *)malloc(cookieSize * sizeof(char));
        //        UInt32 *cookie = (UInt32 *)malloc(cookieSize * sizeof(UInt32));
        error = AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCompressionMagicCookie, &cookieSize, cookie);
        // log4cplus_info("cookie","cookie size status:%d",(int)error);
        
        if (error == noErr) {
            error = AudioFileSetProperty(mRecordFile, kAudioFilePropertyMagicCookieData, cookieSize, cookie);
            // log4cplus_info("cookie","set cookie status:%d ",(int)error);
            if (error == noErr) {
                UInt32 willEatTheCookie = false;
                error = AudioFileGetPropertyInfo(mRecordFile, kAudioFilePropertyMagicCookieData, NULL, &willEatTheCookie);
                printf("Writing magic cookie to destination file: %u\n   cookie:%d \n", (unsigned int)cookieSize, willEatTheCookie);
            } else {
                printf("Even though some formats have cookies, some files don't take them and that's OK\n");
            }
        } else {
            printf("Could not Get kAudioConverterCompressionMagicCookie from Audio Converter!\n");
        }
        
        free(cookie);
    }
}
```

> Magic cookie 是一种不透明的数据格式，它和压缩数据文件与流联系密切，如果文件数据为CBR格式（无损），则不需要添加头部信息，如果为VBR需要添加

### 5.AudioQueue中注册的回调函数

```
// AudioQueue中注册的回调函数
static void inputBufferHandler(void *                                 inUserData,
                               AudioQueueRef                          inAQ,
                               AudioQueueBufferRef                    inBuffer,
                               const AudioTimeStamp *                 inStartTime,
                               UInt32                                 inNumPackets,
                               const AudioStreamPacketDescription*	  inPacketDesc) {
    // 相当于本类对象实例
    TVURecorder *recoder        = (TVURecorder *)inUserData;
    
    // collect pcm data，可以使用不用方式在此存储pcm原始数据
    // XDXSignaling::getInstance()->EnQueue(&collectPcmQueue, (const char*)inBuffer->mAudioData, inBuffer->mAudioDataByteSize, KSignalingTypeLogin);
  

// 将PCM数据转换为AAC
    AudioBufferList *bufferList = convertPCMToAAC(inBuffer, recoder);
    // 释放内存，需要按层次释放，不懂请回顾C语言
    free(bufferList->mBuffers[0].mData);
    free(bufferList);
    //begin write audio data for record audio only
    
    // 出队
    AudioQueueRef queue = recoder.mQueue;
    if (recoder.isRunning) {
        AudioQueueEnqueueBuffer(queue, inBuffer, 0, NULL);
    }
}
```
> 解析回调函数：相当于中断服务函数，每次录取到音频数据就进入这个函数  

  注意：inNumPackets 总包数：音频队列缓冲区大小 （在先前估算缓存区大小为2048）/ （dataFormat.mFramesPerPacket (采集数据每个包中有多少帧，此处在初始化设置中为1) * dataFormat.mBytesPerFrame（每一帧中有多少个字节，此处在初始化设置中为每一帧中两个字节）），所以用捕捉PCM数据时inNumPackets为1024。如果采集的数据是PCM需要将dataFormat.mFramesPerPacket设置为1，而本例中最终要的数据为AAC,在AAC格式下需要将mFramesPerPacket设置为1024.也就是采集到的inNumPackets为1，所以inNumPackets这个参数在此处可以忽略，因为在转换器中传入的inNumPackets应该为AAC格式下默认的1，在此后写入文件中也应该传的是转换好的inNumPackets。

- inAQ 是调用回调函数的音频队列  
- inBuffer 是一个被音频队列填充新的音频数据的音频队列缓冲区，它包含了回调函数写入文件所需要的新数据  
- inStartTime 是缓冲区中的一采样的参考时间，对于基本的录制，你的毁掉函数不会使用这个参数  
- inNumPackets是inPacketDescs参数中包描述符（packet descriptions）的数量，如果你正在录制一个VBR(可变比特率（variable bitrate））格式, 音频队列将会提供这个参数给你的回调函数，这个参数可以让你传递给AudioFileWritePackets函数. CBR (常量比特率（constant bitrate）) 格式不使用包描述符。对于CBR录制，音频队列会设置这个参数并且将inPacketDescs这个参数设置为NULL，官方解释为The number of packets of audio data sent to the callback in the inBuffer parameter.

```
// PCM -> AAC
AudioBufferList* convertPCMToAAC (AudioQueueBufferRef inBuffer, XDXRecorder *recoder) {
    
    UInt32   maxPacketSize    = 0;
    UInt32   size             = sizeof(maxPacketSize);
    OSStatus status;
    
    status = AudioConverterGetProperty(_encodeConvertRef,
                                       kAudioConverterPropertyMaximumOutputPacketSize,
                                       &size,
                                       &maxPacketSize);
    // log4cplus_info("AudioConverter","kAudioConverterPropertyMaximumOutputPacketSize status:%d \n",(int)status);
    
// 初始化一个bufferList存储数据
    AudioBufferList *bufferList             = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers              = 1;
    bufferList->mBuffers[0].mNumberChannels = _targetDes.mChannelsPerFrame;
    bufferList->mBuffers[0].mData           = malloc(maxPacketSize);
    bufferList->mBuffers[0].mDataByteSize   = inBuffer->mAudioDataByteSize;

    AudioStreamPacketDescription outputPacketDescriptions;
    
    /* inNumPackets设置为1表示编码产生1帧数据即返回，官方：On entry, the capacity of 
	outOutputData expressed in packets in the converter's output format. On exit,
	 the number of packets of converted data that were written to outOutputData.
	  在输入表示输出数据的最大容纳能力 在转换器的输出格式上，在转换完成时表示多少个包被写入
	*/
    UInt32 inNumPackets = 1;
    status = AudioConverterFillComplexBuffer(_encodeConvertRef,
                                             encodeConverterComplexInputDataProc,	// 填充数据的回调函数
                                             inBuffer->mAudioData,		// 音频队列缓冲区中数据
                                             &inNumPackets,		
                                             bufferList,			// 成功后将值赋给bufferList
                                             &outputPacketDescriptions);	// 输出包包含的一些信息
    log4cplus_info("AudioConverter","set AudioConverterFillComplexBuffer status:%d",(int)status);
    
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
        // log4cplus_info("write file","write file status = %d",(int)status);
        if (status == noErr) {
            recoder.mRecordPacket += inNumPackets;  // 用于记录起始位置
        }
    }

    return bufferList;
}
```
> 解析

 outputPacketDescriptions数组是每次转换的AAC编码后各个包的描述,但这里每次只转换一包数据(由传入的packetSize决定)。调用AudioConverterFillComplexBuffer触发转码，他的第二个参数是填充原始音频数据的回调。转码完成后，会将转码的数据存放在它的第五个参数中(bufferList).
 
 ```
 // 录制声音功能
 -(void)startVoiceDemo
{
    NSArray *searchPaths    = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath  = [[searchPaths objectAtIndex:0] stringByAppendingPathComponent:@"VoiceDemo"];
    OSStatus status;
    
    // Get the full path to our file.
    NSString *fullFileName  = [NSString stringWithFormat:@"%@.%@",[[XDXDateTool shareXDXDateTool] getDateWithFormat_yyyy_MM_dd_HH_mm_ss],@"caf"];
    NSString *filePath      = [documentPath stringByAppendingPathComponent:fullFileName];
    [mRecordFilePath release];
    mRecordFilePath         = [filePath copy];;
    CFURLRef url            = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)filePath, NULL);
    
    // create the audio file
    status                  = AudioFileCreateWithURL(url, kAudioFileMPEG4Type, &_targetDes, kAudioFileFlags_EraseFile, &mRecordFile);
    if (status != noErr) {
        // log4cplus_info("Audio Recoder","AudioFileCreateWithURL Failed, status:%d",(int)status);
    }
    
    CFRelease(url);
    
    // add magic cookie contain header file info for VBR data
    [self copyEncoderCookieToFile];
    
    mNeedsVoiceDemo         = YES;
    NSLog(@"%s",__FUNCTION__);
}
 ```
 
 
### 总结：第一次接触音频类程序底层的处理，首先看了很多相关博客，简书，然后manager让我通读CoreAudio官方文档，感觉受益颇大，很多优秀的文章都是把苹果官方文档[Core Audio](https://developer.apple.com/library/content/documentation/MusicAudio/Conceptual/CoreAudioOverview/CoreAudioEssentials/CoreAudioEssentials.html)内容翻译，包括苹果给的图都很形象，建议有时间的朋友可以通读一下，每个人的需求不同，做的过程中遇到的问题肯定不同，只有理解了每个参数的含义才能灵活的控制代码，希望可以帮到大家，喜欢的可以转载。
