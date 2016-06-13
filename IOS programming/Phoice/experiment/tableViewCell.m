//
//  tableViewCell.m
//  experiment
//
//  Created by Qi Hu on 16/5/16.
//  Copyright © 2016 Qi Hu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "tableViewCell.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import "MZTimerLabel.h"
#import "SCSiriWaveformView.h"


@interface tableViewCell ()<AVAudioRecorderDelegate, AVAudioPlayerDelegate>

@end

@implementation tableViewCell

-(instancetype) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]){
//        int index = arc4random_uniform((int)self.photoArray.count);
//        NSString *str = self.photoArray[index];
//        NSURL *url = [NSURL URLWithString:str];
//        UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
//        //UIImageView *imageShown = [[UIImageView alloc]initWithImage:image];
//        self.imageView.image = image;
//        
//        self.textLabel.text = [NSString stringWithFormat:@"%d", index];
//        
//        photoItem *item = self.photoArray[index];
//        self.detailTextLabel.text = item.address;
        
        
        //[self.contentView addSubview: imageShown];
    }
    
    return self;
}

-(void)layoutSubviews{
    
    [super layoutSubviews];
    
    //overload the imageview's style
    //need both bounds and frame
    //not a laptop version
    self.imageView.bounds = CGRectMake(10,10,80,80);
    self.imageView.frame =CGRectMake(10,10,80,80);
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.clipsToBounds = YES;
    
    CGRect tmpFrame = self.textLabel.frame;
    tmpFrame.origin.x = 130;
    self.textLabel.frame = tmpFrame;
    
    tmpFrame = self.detailTextLabel.frame;
    tmpFrame.origin.x = 130;
    self.detailTextLabel.frame = tmpFrame;
    
    self.layer.borderWidth = 3;
    self.layer.borderColor = [[UIColor clearColor]CGColor];
    
    self.selectionStyle = UITableViewCellSelectionStyleGray;
    
    self.separatorInset = UIEdgeInsetsMake(0, 3, 0, 11);
}



@end