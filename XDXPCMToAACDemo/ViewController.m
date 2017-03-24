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

@interface ViewController ()

@property (nonatomic,retain) XDXRecorder *liveRecorder;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self configureAudio];
    [self.liveRecorder startRecorder];
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



@end
