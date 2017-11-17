//
//  ViewController.m
//  XDXPCMToAACDemo
//
//  Created by demon on 23/03/2017.
//
//

#import "ViewController.h"
#import "XDXRecoder.h"
#import <AVFoundation/AVFoundation.h>
#import "XDXVolumeView.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height


@interface ViewController ()

@property (nonatomic, strong) XDXRecorder    *liveRecorder;
@property (nonatomic, strong) XDXVolumeView  *recordVolumeView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self configureAudio];
    /*
        注意，本例中XDXRecorder中分别用AudioQueue与AudioUnit实现了录音，区别好处在博客简书中均有介绍，在此不再重复，请根据需要选择。
     */
    
    self.liveRecorder = [[XDXRecorder alloc] init];
    
#warning You need select use Audio Unit or Audio Queue
    self.liveRecorder.releaseMethod = XDXRecorderReleaseMethodAudioQueue;
    
    [self initVoumeView];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)configureAudio
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    BOOL success;
    NSError* error;
    
    success = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker|AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionMixWithOthers error:&error];
    
    if (self.liveRecorder.releaseMethod == XDXRecorderReleaseMethodAudioUnit) {
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionMixWithOthers error:&error];
        [audioSession setPreferredIOBufferDuration:0.01 error:&error]; // 10ms采集一次
        [audioSession setPreferredSampleRate:48000 error:&error];  // 需和XDXRecorder中对应
    }
    
    //set USB AUDIO device as high priority: iRig mic HD
    for (AVAudioSessionPortDescription *inputPort in [audioSession availableInputs])
    {
        if([inputPort.portType isEqualToString:AVAudioSessionPortUSBAudio])
        {
            [audioSession setPreferredInput:inputPort error:&error];
            //log4cplus_error("aac", "setPreferredInput status:%s\n", error.debugDescription.UTF8String);
            [audioSession setPreferredInputNumberOfChannels:2 error:&error];
            //log4cplus_error("aac", "setPreferredInputNumberOfChannels status:%s\n", error.debugDescription.UTF8String);
            break;
        }
    }
    
    if(!success)
        NSLog(@"AVAudioSession error setCategory = %@",error.debugDescription);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
    
    success = [audioSession setActive:YES error:&error];
    
    //Restrore default audio output to BuildinReceiver
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription *portDesc in [currentRoute outputs])
    {
        if([portDesc.portType isEqualToString:AVAudioSessionPortBuiltInReceiver])
        {
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
            break;
        }
    }
    
}

- (void)audioRouteChanged:(NSNotification*)notify {
    NSDictionary *dic = notify.userInfo;
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    AVAudioSessionRouteDescription *oldRoute = [dic objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    NSNumber *routeChangeReason = [dic objectForKey:AVAudioSessionRouteChangeReasonKey];
    NSLog(@"audio route changed: reason: %@\n input:%@->%@, output:%@->%@",routeChangeReason,oldRoute.inputs,currentRoute.inputs,oldRoute.outputs,currentRoute.outputs);

}

- (IBAction)startAudio:(id)sender {
    if (self.liveRecorder.releaseMethod == XDXRecorderReleaseMethodAudioUnit) {
        [self.liveRecorder startAudioUnitRecorder];
    }else if (self.liveRecorder.releaseMethod == XDXRecorderReleaseMethodAudioQueue) {
        [self.liveRecorder startAudioQueueRecorder];
    }
}

- (IBAction)endAudio:(id)sender {
    if (self.liveRecorder.releaseMethod == XDXRecorderReleaseMethodAudioUnit) {
        [self.liveRecorder stopAudioUnitRecorder];
    }else if (self.liveRecorder.releaseMethod == XDXRecorderReleaseMethodAudioQueue) {
        [self.liveRecorder stopAudioQueueRecorder];
    }
}

#pragma mark - Volume
- (void)initVoumeView {
    CGFloat volumeHeight    = 5;
    CGFloat dockViewWidth   = 394;
    CGFloat volumeX         = (kScreenWidth - dockViewWidth) / 2;
    self.recordVolumeView   = [[XDXVolumeView alloc] initWithFrame:CGRectMake(0, kScreenHeight - volumeHeight, kScreenWidth, volumeHeight)];
    
    [self.view addSubview:self.recordVolumeView];
    
    [NSTimer scheduledTimerWithTimeInterval:0.25f target:self selector:@selector(updateVolume) userInfo:nil repeats:YES];
}

-(void)updateVolume {
    
    CGFloat volumeRecord = self.liveRecorder.volLDB;
    
    if(volumeRecord >= -40 && volumeRecord <= 0) {
        volumeRecord = volumeRecord + 40;
    } else if(volumeRecord > 0) {
        volumeRecord = 40;
    } else {
        volumeRecord = 0;
    }
    
//    log4cplus_debug("Volume View","volumeRecord is %f, volumeR is %f",volumeRecord, volumePlay);
    [self.recordVolumeView setCurrentVolumn:volumeRecord    isRecord:YES];
}

@end
