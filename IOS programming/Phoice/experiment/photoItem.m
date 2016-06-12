//
//  photoItem.m
//  experiment
//
//  Created by Qi Hu on 16/5/16.
//  Copyright © 2016 Qi Hu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "photoItem.h"


@interface photoItem ()

@end

@implementation photoItem{
    //for recorder
    BOOL pausedState;
    NSString *previousMode;
    
    UIVisualEffectView *visualEffectView;
    SCSiriWaveformView *waveView;
    CADisplayLink *meterUpdateDisplayLink;
}

-(void) initializeRecorder{
    NSMutableDictionary *_dict = [NSMutableDictionary dictionary];
    
    [_dict setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    
    [_dict setObject:@(8000) forKey:AVSampleRateKey];
    
    [_dict setObject:@(1) forKey:AVNumberOfChannelsKey];
    
    [_dict setObject:@(8) forKey:AVLinearPCMBitDepthKey];
    
    [_dict setObject:@(YES) forKey:AVLinearPCMIsFloatKey];
    
    NSError *error;
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:self.audioAddress] settings:_dict error:&error];
    _audioRecorder.delegate = self;
    _audioRecorder.meteringEnabled = YES;
    NSLog(@"%@",error);
    
}


-(void) initializePlayer{
    //initialize the audioPlayer
    previousMode = [AVAudioSession sharedInstance].category;
    NSError *error;
    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback error:&error];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    if (_audioPlayer == nil){
        _audioPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:self.audioAddress] error:nil];
        _audioPlayer.delegate = self;
        _audioPlayer.meteringEnabled = YES;
    }
    
    if (error){
        NSLog(@"%@", error);
    }
}

- (void)validateMicrophoneAccess{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    if ([session respondsToSelector:@selector(requestRecordPermission:)]){
        
        [session requestRecordPermission:^(BOOL granted) {
            
            if (granted){
                NSLog(@"microphone access granted");
                //microPhoneAccess = granted;
            }
            else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[[UIAlertView alloc] initWithTitle:@"无法录音" message:@"请在“设置-隐私-麦克风”选项中允许xx访问你的麦克风" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] show];
                });
            }
        }];
    }

}

-(void)startUpdatingMeter
{
    [meterUpdateDisplayLink invalidate];
    meterUpdateDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMeters)];
    [meterUpdateDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

-(void)stopUpdatingMeter
{
    [meterUpdateDisplayLink invalidate];
    meterUpdateDisplayLink = nil;
}

-(void)updateMeters{
    if (_audioRecorder.isRecording || pausedState){
        [_audioRecorder updateMeters];
        
        CGFloat normalizedValue = pow (10, [_audioRecorder averagePowerForChannel:0] / 20);
        
        waveView.waveColor = [UIColor blueColor];
        [waveView updateWithLevel:normalizedValue];
    }
    
    else if (_audioPlayer){
        [_audioPlayer updateMeters];
        CGFloat normalizedValue = pow (10, [_audioPlayer averagePowerForChannel:0] / 20);
        waveView.waveColor = [UIColor redColor];
        //waveView.tintColor = [UIColor whiteColor];
        [waveView updateWithLevel:normalizedValue];
    }
    
    else {
        waveView.waveColor = [UIColor whiteColor];
        [waveView updateWithLevel:0];
    }
}

-(SCSiriWaveformView *) initializeWaveView{
    
    waveView = [[SCSiriWaveformView alloc]initWithFrame:visualEffectView.contentView.bounds];
    waveView.alpha = 1;
    waveView.backgroundColor = [UIColor clearColor];
    waveView.primaryWaveLineWidth = 0.3f;
    waveView.secondaryWaveLineWidth = 1.0;
    waveView.waveColor = [UIColor greenColor];
    
    
    return waveView;
}

-(UIVisualEffectView*) initializeVEViewWithFrame: (CGRect) rect{
    //setup visualEffectView
    visualEffectView = [[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    visualEffectView.frame = rect;

    waveView = [[SCSiriWaveformView alloc]initWithFrame:visualEffectView.contentView.bounds];
    waveView.alpha = 1;
    waveView.backgroundColor = [UIColor clearColor];
    waveView.primaryWaveLineWidth = 0.3f;
    waveView.secondaryWaveLineWidth = 1.0;
    waveView.waveColor = [UIColor whiteColor];
    [visualEffectView.contentView addSubview:waveView];
    
    return visualEffectView;
}

-(void) initializeAudioSession{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    [audioSession setActive:YES error:nil];
}


- (void)recordClick:(UIButton *)sender {
    
    
    if (!_audioRecorder){
        [self initializeRecorder];
    }
    
    //check if there are existing files at the filepath
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.audioAddress]){
        [[NSFileManager defaultManager] removeItemAtPath:self.audioAddress error:nil];
        NSLog(@"previous recording removed");
    }
    
    previousMode = [AVAudioSession sharedInstance].category;
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryRecord error:nil];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [_audioRecorder prepareToRecord];
    
    pausedState = YES;
    
    [_audioRecorder record];
}


- (void)pauseClick:(UIButton *)sender {
    
    pausedState = YES;
    [_audioRecorder pause];
}


- (void)resumeClick:(UIButton *)sender {
    
    pausedState = NO;
    [_audioRecorder record];
    
}


- (void)stopClick:(UIButton *)sender {
    pausedState = NO;
    [_audioRecorder stop];
    
}


-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{
    
    if (flag){
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.audioAddress]){
            NSLog(@"Recording successful!");
        }
        
        [[AVAudioSession sharedInstance] setCategory:previousMode error:nil];
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
}

-(void)playRecording:(UIButton*)sender{
    
    if (!_audioPlayer){
        [self initializePlayer];
    }
    
    [_audioPlayer prepareToPlay];
    [_audioPlayer play];
    
    NSLog(@"playing");
}

-(void)pauseRecording : (UIButton*) sender {
    if ([_audioPlayer isPlaying]){
        [_audioPlayer pause];
        NSLog(@"playback paused");
    }
    
//    else if (![_audioPlayer isPlaying]){
//        [_audioPlayer play];
//        NSLog(@"playback resumed");
//    }
}




-(void) stopRecording : (UIButton *) sender {
    
    _audioPlayer.delegate = nil;
    [_audioPlayer stop];
    _audioPlayer = nil;
    
    [[AVAudioSession sharedInstance] setCategory:previousMode error:nil];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    NSLog(@"playback stopped!");
}


-(void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    if (flag){
        if (_audioPlayer){
            _audioPlayer.delegate = nil;
            [_audioPlayer stop];
            _audioPlayer = nil;
            
            [[AVAudioSession sharedInstance] setCategory:previousMode error:nil];
            [UIApplication sharedApplication].idleTimerDisabled = NO;
            NSLog(@"audioPlayer deleted");
        }
        NSLog(@"playback successful!");
    }
    else {
        NSLog(@"playback failed somehow");
    }
}

@end