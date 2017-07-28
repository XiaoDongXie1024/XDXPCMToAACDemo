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

typedef NS_ENUM(NSInteger, XDXRecorderReleaseMethod) {
    XDXRecorderReleaseMethodAudioUnit,
    XDXRecorderReleaseMethodAudioQueue,
};

@class XDXRecorder;

@protocol XDXRecoderDelegate

-(void)onRecorder:(XDXRecorder *)aRecorder didGetQueueData:(Byte *)bytes withSize:(int) size;

@end

@interface XDXRecorder : NSObject
{
    
    AudioStreamBasicDescription     dataFormat;

    BOOL                            isRunning;
    UInt64                          startTime;
    Float64                         hostTime;
    
    //state for voice memo
    NSString *                      mRecordFilePath;
    AudioFileID                     mRecordFile;
    SInt64                          mRecordPacket;      // current packet number in record file
    BOOL                            mNeedsVoiceDemo;
    
    // AudioQueue
    AudioQueueRef                   mQueue;
    AudioQueueBufferRef             mBuffers[kNumberQueueBuffers];
    
    // AudioUnit
    @public
    AudioUnit                        _audioUnit;
    AudioBufferList                 *_buffList;
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

// 区分使用AudioQueue或AudioUnit
@property (nonatomic, assign)       XDXRecorderReleaseMethod        releaseMethod;

-(id)initWithFormatID:(UInt32)formatID;
-(BOOL)isRunning;

-(void)startVoiceDemo;
-(void)stopVoiceDemo;


// AudioQueue
- (void)startAudioQueueRecorder;
- (void)stopAudioQueueRecorder;


// AudioUnit
- (void)startAudioUnitRecorder;
- (void)stopAudioUnitRecorder;

@end
