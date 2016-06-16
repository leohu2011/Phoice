//
//  photoItem.h
//  experiment
//
//  Created by Qi Hu on 16/5/16.
//  Copyright © 2016 Qi Hu. All rights reserved.
//

#ifndef photoItem_h
#define photoItem_h
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import "SCSiriWaveformView.h"



@interface photoItem : NSObject <AVAudioRecorderDelegate, AVAudioPlayerDelegate>{

}

@property (nonatomic, copy) NSString *photoAddress;
@property (nonatomic, strong) NSData *big_photo_data;
@property (nonatomic, strong) NSData *small_photo_data;

@property (nonatomic, copy) NSString *audioAddress;

@property (nonatomic, assign) NSInteger itemIndex;

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;


//initialization
-(void) initializeRecorder;

-(void) initializePlayer;

-(void) validateMicrophoneAccess;

-(void) initializeAudioSession;

-(SCSiriWaveformView *) initializeWaveView;

-(UIVisualEffectView*) initializeVEViewWithFrame: (CGRect) rect;

-(void)startUpdatingMeter;

-(void)stopUpdatingMeter;

-(void)updateMeters;


//recorder
- (void)recordClick:(UIButton *)sender;

- (void)pauseClick:(UIButton *)sender;

- (void)resumeClick:(UIButton *)sender;

- (void)stopClick:(UIButton *)sender;


//player
-(void)playRecording:(UIButton*)sender;

-(void)pauseRecording : (UIButton*) sender;

-(void) stopRecording : (UIButton *) sender;


@end


#endif /* photoItem_h */
