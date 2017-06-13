//
//  XDXRecoder.h
//  XDXPCMToAACDemo
//
//  Created by 小东邪 on 23/03/2017.
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define kNumberQueueBuffers 3

@class XDXRecorder;

@protocol XDXRecoderDelegate

-(void)onRecorder:(XDXRecorder *)aRecorder didGetQueueData:(Byte *)bytes withSize:(int) size;

@end

@interface XDXRecorder : NSObject
{
    AudioStreamBasicDescription     dataFormat;
    AudioQueueRef                   mQueue;
    AudioQueueBufferRef             mBuffers[kNumberQueueBuffers];
    
    BOOL                            isRunning;
    UInt64                          startTime;
//    id<XDXRecoderDelegate>          delegate;
    NSString *                      rawFilePath;
    
    Float64                         hostTime;
    
    //state for voice memo
    NSString *                      mRecordFilePath;
    AudioFileID                     mRecordFile;
    SInt64                          mRecordPacket;      // current packet number in record file
    BOOL                            mNeedsVoiceDemo;
}

@property (nonatomic ,assign)       id<XDXRecoderDelegate>          delegate;
@property (readonly)                BOOL                            isRunning;
@property (readonly)                UInt64                          startTime;
@property (readonly)                AudioStreamBasicDescription     dataFormat;
@property (readonly)                AudioQueueRef                   mQueue;
@property (readonly)                BOOL                            isRecordingVoiceMemo;
@property (nonatomic ,retain)       NSString*                       rawFilePath;

@property (nonatomic ,assign)       Float64                         hostTime;
@property (nonatomic ,assign)       AudioFileID                     mRecordFile;
@property (nonatomic ,assign)       SInt64                          mRecordPacket;
@property (readonly)                BOOL                            needsVoiceDemo;

-(id)initWithFormatID:(UInt32)formatID;
-(void)startRecorder;
-(void)stopRecorder;
-(BOOL)isRunning;

-(void)startVoiceDemo;
-(void)stopVoiceDemo;

@end
