//
//  detailView.m
//  experiment
//
//  Created by Qi Hu on 17/5/16.
//  Copyright © 2016 Qi Hu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "detailViewController.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import "MZTimerLabel.h"
#import "SCSiriWaveformView.h"
#import "photoItem.h"
#import "detailViewController+CreateBtn.h"

@interface detailViewController()<UIScrollViewDelegate,AVAudioRecorderDelegate, AVAudioPlayerDelegate>

@end

@implementation detailViewController{
    NSIndexPath *pathChosen;
    UIScrollView *scrollView;
    UIImageView *returnImageView;
    UIImageView *enlargeView;
    CGRect originalFrame;
    
    //photoItem object
    photoItem *photo_audio_Item;
    
    
    //other supporting features
    UILabel *timeLabel;
    MZTimerLabel *MZtimer2;
    UIVisualEffectView *visualEffectView;
    SCSiriWaveformView *waveView;
    CADisplayLink *meterUpdateDisplayLink;
    
    //recorder
    AVAudioRecorder *_audioRecorder;
    UIButton *recordR;
    UIButton *pauseR;
    UIButton *resumeR;
    UIButton *stopR;
    BOOL pausedState;
    NSString *previousMode;
    
    //player
    AVAudioPlayer *_audioPlayer;
    UIButton *recordP;
    UIButton *pauseP;
    UIButton *resumeP;
    UIButton *stopP;
}

-(instancetype) initWithIndex:(NSIndexPath*)indexpath andAddress: (NSString*) address{
    
    if (self = [super init]) {
    
        pathChosen = indexpath;

    }
    return self;
}

-(void) viewDidLoad{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self loadPhotoItemObject];
    [self initializeEditAndImage];
    [self initialize_btnAndLabel];
}


-(void) loadPhotoItemObject{
    photo_audio_Item = [[photoItem alloc]init];

    
    photo_audio_Item.audioAddress = self.audioLocation;
    photo_audio_Item.photoAddress = self.photoLocation;
    photo_audio_Item.itemIndex = (NSInteger) pathChosen.row;
    

    
    //[photo_audio_Item validateMicrophoneAccess];
    [photo_audio_Item initializeAudioSession];
    [photo_audio_Item startUpdatingMeter];
    
    CGRect rect = CGRectMake(10, 300, [UIScreen mainScreen].bounds.size.width - 20, 200);
    visualEffectView = [photo_audio_Item initializeVEViewWithFrame:rect];
    [self.view addSubview:visualEffectView];
    
}

-(void)initializeEditAndImage{
    UITapGestureRecognizer *doubleClick = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTap:)];
    doubleClick.numberOfTapsRequired = 1;
    
    //setup detail image view
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    int index = (int)pathChosen.row;
    
//    NSURL *url;
//    if ([self.photoLocation containsString:@"thumbnail"]){
//        url = [[NSURL alloc]initWithString:[self.photoLocation stringByReplacingOccurrencesOfString:@"thumbnail" withString:@"bmiddle"]];
//    }
//    else{
//        url = [[NSURL alloc]initWithString:self.photoLocation];
//    }
//    NSData *data = [[NSData alloc]initWithContentsOfURL: url];
//    UIImage *img = [[UIImage alloc]initWithData:data];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSString *Plist_filePath = [documentDirectory stringByAppendingPathComponent:@"image.plist"];
    
    NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
    NSData *big_data;
    for (NSArray *arr in mainArray){
        if ([arr[2] isEqualToString:self.photoLocation]){
            big_data = arr[1];
            break;
        }
    }
    UIImage *img = [[UIImage alloc]initWithData:big_data];
    
    UIImageView *imgView = [[UIImageView alloc]initWithImage:img];
    imgView.frame = (CGRectMake(0, 0, width * 0.5, self.view.frame.size.height *0.3));
    imgView.center = CGPointMake(width/2 + 50, 180);
    imgView.userInteractionEnabled = YES;
    imgView.multipleTouchEnabled = YES;
    [imgView addGestureRecognizer:doubleClick];
    [self.view addSubview: imgView];
    
    //edit cell information
    UITapGestureRecognizer *singleClick = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(singleTap:)];
    singleClick.numberOfTapsRequired = 1;
    
    UILabel *label = [[UILabel alloc]initWithFrame:(CGRect){10,180,100,50}];
    label.text = @"Edit Cell Info";
    label.font = [UIFont boldSystemFontOfSize:15];
    label.textColor = [UIColor blueColor];
    label.tag = index;
    label.userInteractionEnabled = YES;
    label.multipleTouchEnabled = YES;
    [label addGestureRecognizer:singleClick];
    [self.view addSubview:label];
}


-(void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    //[photo_audio_Item validateMicrophoneAccess];

}

-(void)initialize_btnAndLabel{
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    
    //time label
    timeLabel = [[UILabel alloc]initWithFrame:(CGRect){10, height - 150, 200, 50}];
    timeLabel.center = CGPointMake([UIScreen mainScreen].bounds.size.width/2, 50);
    timeLabel.textAlignment = NSTextAlignmentLeft;
    timeLabel.textColor = [UIColor blackColor];
    timeLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.view addSubview: timeLabel];
    
    //recorder buttons
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:15.0f];
    

    recordR = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [recordR setTitle:@"Record" forState:UIControlStateNormal];
    [recordR setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    recordR.backgroundColor = [UIColor clearColor];
    recordR.titleLabel.font = font;
    CGSize size = [recordR.titleLabel.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
    recordR.frame = CGRectMake(10, height-80 ,size.width +10, size.height + 10);
    UITapGestureRecognizer *record = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(recordClick:)];
    [recordR addGestureRecognizer:record];
    recordR.userInteractionEnabled = YES;
    [self.view addSubview:recordR];
    
    pauseR = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [pauseR setTitle:@"Pause" forState:UIControlStateNormal];
    [pauseR setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    pauseR.backgroundColor = [UIColor clearColor];
    pauseR.titleLabel.font = font;
    size = [pauseR.titleLabel.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
    pauseR.frame = CGRectMake(width*0.25 + 10, height-80 ,size.width +10, size.height + 10);
    UITapGestureRecognizer *pause = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(pauseClick:)];
    [pauseR addGestureRecognizer:pause];
    pauseR.userInteractionEnabled = YES;
    [self.view addSubview:pauseR];
    
    resumeR = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [resumeR setTitle:@"Resume" forState:UIControlStateNormal];
    [resumeR setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    resumeR.backgroundColor = [UIColor clearColor];
    resumeR.titleLabel.font = font;
    size = [resumeR.titleLabel.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
    resumeR.frame = CGRectMake(width*0.5 + 10, height-80 ,size.width +10, size.height + 10);
    UITapGestureRecognizer *resume = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(resumeClick:)];
    [resumeR addGestureRecognizer:resume];
    resumeR.userInteractionEnabled = YES;
    [self.view addSubview:resumeR];
    
    stopR = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [stopR setTitle:@"Stop" forState:UIControlStateNormal];
    [stopR setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    stopR.backgroundColor = [UIColor clearColor];
    stopR.titleLabel.font = font;
    size = [stopR.titleLabel.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
    stopR.frame = CGRectMake(width*0.75 + 10, height-80 ,size.width +10, size.height + 10);
    UITapGestureRecognizer *stop = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(stopClick:)];
    [stopR addGestureRecognizer:stop];
    stopR.userInteractionEnabled = YES;
    [self.view addSubview:stopR];
    
    //player buttons
    recordP = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [recordP setTitle:@"Play" forState:UIControlStateNormal];
    [recordP setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    recordP.backgroundColor = [UIColor clearColor];
    recordP.titleLabel.font = font;
    size = [recordP.titleLabel.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
    recordP.frame = CGRectMake(10, height-120 ,size.width +10, size.height + 10);
    UITapGestureRecognizer *Play = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(playRecording:)];
    [recordP addGestureRecognizer:Play];
    recordP.userInteractionEnabled = YES;
    [self.view addSubview:recordP];
    
    pauseP = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [pauseP setTitle:@"Pause" forState:UIControlStateNormal];
    [pauseP setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    pauseP.backgroundColor = [UIColor clearColor];
    pauseP.titleLabel.font = font;
    size = [pauseP.titleLabel.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
    pauseP.frame = CGRectMake(width*0.25 + 10, height-120 ,size.width +10, size.height + 10);
    UITapGestureRecognizer *pausePlaying = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(pauseRecording:)];
    [pauseP addGestureRecognizer:pausePlaying];

    [self.view addSubview:pauseP];
    
//    resumeP = [UIButton buttonWithType:UIButtonTypeRoundedRect];
//    [resumeP setTitle:@"Resume" forState:UIControlStateNormal];
//    [resumeP setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
//    resumeP.backgroundColor = [UIColor clearColor];
//    resumeP.titleLabel.font = font;
//    size = [resumeP.titleLabel.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
//    resumeP.frame = CGRectMake(width*0.5 + 10, height-120 ,size.width +10, size.height + 10);
//    [self.view addSubview:resumeP];
    
    stopP = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [stopP setTitle:@"Stop" forState:UIControlStateNormal];
    [stopP setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    stopP.backgroundColor = [UIColor clearColor];
    stopP.titleLabel.font = font;
    size = [stopP.titleLabel.text sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
    stopP.frame = CGRectMake(width*0.75 + 10, height-120 ,size.width +10, size.height + 10);
    UITapGestureRecognizer *Stop = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(stopRecording:)];
    [stopP addGestureRecognizer:Stop];
    stopP.userInteractionEnabled = YES;
    [self.view addSubview:stopP];
}

//recorder
- (void)recordClick:(UIButton *)sender{
    [photo_audio_Item validateMicrophoneAccess];
    [photo_audio_Item recordClick:sender];
}

- (void)pauseClick:(UIButton *)sender{
    [photo_audio_Item pauseClick:sender];
}

- (void)resumeClick:(UIButton *)sender{
    [photo_audio_Item resumeClick:sender];
}

- (void)stopClick:(UIButton *)sender{
    [photo_audio_Item stopClick:sender];
}


//player
-(void)playRecording:(UIButton*)sender{
    [photo_audio_Item playRecording:sender];
}

-(void) stopRecording : (UIButton *) sender{
    [photo_audio_Item stopRecording:sender];
}

-(void)pauseRecording: (UIButton*) sender{
    [photo_audio_Item pauseRecording:sender];
}


-(void)singleTap : (UITapGestureRecognizer*)recognizer{
    
    UILabel *lbl = [self.view viewWithTag:(int)pathChosen.row];
    
    if ([lbl isKindOfClass:[UILabel class]]){
        lbl.textColor = [UIColor redColor];
    }
    
    
    //prompt the user to change info
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"This is an Alert" message:@"change of info" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * textField){
        textField.placeholder = @"textLabel";
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * textField){
        textField.placeholder = @"detailInfo";
    }];
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act){
        UITextField *text1 = alert.textFields.firstObject;
        UITextField *text2 = alert.textFields.lastObject;
        
    [self.delegate changeCellInfoWithText:text1.text andDetailInfo:text2.text onIndexPath:pathChosen];
        
    }];
    UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:action];
    [alert addAction:action2];
    
    [self presentViewController:alert animated:YES completion:nil];

}

-(void)doubleTap : (UITapGestureRecognizer*)recognizer{
    
    //setup the background scroll view
    UIScrollView *bgView = [[UIScrollView alloc]init];
    //bgView.bounds = [UIScreen mainScreen].bounds;
    bgView.frame = (CGRect){0,0,self.view.bounds.size.width, self.view.bounds.size
        .height};
    bgView.backgroundColor = [UIColor blackColor];
    UITapGestureRecognizer *returnBack = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(goBack:)];
    [bgView addGestureRecognizer:returnBack];
    
    enlargeView = (UIImageView*)recognizer.view;
    
    UIImageView *imageView = [[UIImageView alloc]init];
    imageView.image = enlargeView.image;
    imageView.frame = [bgView convertRect:enlargeView.frame fromView:self.view];
    [bgView addSubview:imageView];
    
    [self.view addSubview:bgView];
    //[[[UIApplication sharedApplication] keyWindow] addSubview:bgView];
    
    returnImageView = imageView;
    originalFrame = imageView.frame;
    scrollView = bgView;
    scrollView.maximumZoomScale = 2.0;
    scrollView.delegate = self;
    
    [UIView animateWithDuration:0.3 animations:^{
        imageView.frame=CGRectMake(0,([UIScreen mainScreen].bounds.size.height-enlargeView.image.size.height*[UIScreen mainScreen].bounds.size.width/enlargeView.image.size.width)/2,
            [UIScreen mainScreen].bounds.size.width,
            enlargeView.image.size.height*[UIScreen mainScreen].bounds.size.width/enlargeView.image.size.width);
        bgView.alpha=1;
    } completion:^(BOOL finished) {
    }];
}


-(void)goBack:(UITapGestureRecognizer *)tapBgRecognizer
{
    scrollView.contentOffset = CGPointZero;
    [UIView animateWithDuration:0.5 animations:^{
        returnImageView.frame = originalFrame;
        tapBgRecognizer.view.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
        [tapBgRecognizer.view removeFromSuperview];
        scrollView = nil;
        returnImageView = nil;
    }];
}

-(UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return returnImageView;
}




@end