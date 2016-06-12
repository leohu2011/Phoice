//
//  rootViewController.h
//  experiment
//
//  Created by Qi Hu on 16/5/16.
//  Copyright © 2016 Qi Hu. All rights reserved.
//

#ifndef rootViewController_h
#define rootViewController_h
#import <UIKit/UIKit.h>
#import "tableViewCell.h"
#import "photoItem.h"
#import "detailViewController.h"


@interface rootViewController : UIViewController <UITableViewDataSource, UITableViewDelegate,detailViewDelegate>

@property (nonatomic, strong) UITableView *tblView;

@end


#endif /* rootViewController_h */
