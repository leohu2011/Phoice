//
//  rootViewController.m
//  experiment
//
//  Created by Qi Hu on 16/5/16.
//  Copyright © 2016 Qi Hu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "rootViewController.h"
#import "UIImageView+WebCache.h"
#import "detailViewController.h"
#import "FMDatabase.h"

@interface rootViewController()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@end

@implementation rootViewController{
    NSArray *contentArray, *pathArray;
    UIScrollView *scrView;
    UIImageView *imageView;
    UIImageView *beforeView;
    UIImageView *afterView;
    int currentIndex;
    UIPageControl *pageControl;
//    NSIndexPath *currentIndexPath;
    
    UIImagePickerController *imgPickerController;
    UIBarButtonItem *pickImage;
    UIBarButtonItem *flexItem;
    
    //database
    NSString *dbPath;
    FMDatabase *db;
    
    //local cache storage
    NSString *Plist_filePath;
    
}

//next step is to add the loading procedure from database to cache in the startup step in async

-(void)loadView{
    [super loadView];
    
    contentArray = @[@"http://ww2.sinaimg.cn/thumbnail/904c2a35jw1emu3ec7kf8j20c10epjsn.jpg",
                     @"http://ww2.sinaimg.cn/thumbnail/98719e4agw1e5j49zmf21j20c80c8mxi.jpg",
                     @"http://ww2.sinaimg.cn/thumbnail/67307b53jw1epqq3bmwr6j20c80axmy5.jpg",
                     @"http://ww2.sinaimg.cn/thumbnail/9ecab84ejw1emgd5nd6eaj20c80c8q4a.jpg",
                     @"http://ww2.sinaimg.cn/thumbnail/642beb18gw1ep3629gfm0g206o050b2a.gif",
                     @"http://ww1.sinaimg.cn/thumbnail/9be2329dgw1etlyb1yu49j20c82p6qc1.jpg"
                     ];
    [self initializeDataBase];
    
    [self obtainDataFromDB];
    
    [self initializeView];
    
    [self initializeTableView];
    
    [self initiaizeScrollView];
    
    [self initializePageControl];

}

-(void)initializeDataBase{
    //intialize the database
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    dbPath = [documentDirectory stringByAppendingPathComponent:@"MyDatabase.db"];
    db = [FMDatabase databaseWithPath:dbPath] ;
    if (![db open]) {
        NSLog(@"Could not open db.");
        return ;
    }
    
    
    if ([db open]){
        //setup the table
        BOOL b = [db executeUpdate:@"CREATE TABLE IF NOT EXISTS Phoice (ID INTEGER PRIMARY KEY AUTOINCREMENT, Section integer, IndexRow integer, Loaded integer, TextLabel text, DetailDescription text, SmallPhoto blob, SmallPhotoAddress text, BigPhoto blob, BigPhotoAddress text,AudioFile text)"];
        
        if(!b){
            NSLog( @"sb wan er yi wrong again");
        }
        
        int count = 0;
        FMResultSet *result = [db executeQuery:@"select count(*) as NUM from Phoice"];
        if ([result next]){
            count = [result intForColumn: @"NUM"];
        }
        
        //this step is to check if the database has already be initiated
        if (count == 0){
            for(int i = 0; i < contentArray.count; i++){
                NSString *small = contentArray[i];
                NSString *big = [small stringByReplacingOccurrencesOfString:@"thumbnail" withString:@"bmiddle"];
                
                NSURL *url_small = [NSURL URLWithString:small];
                NSData *data_small = [[NSData alloc]initWithContentsOfURL:url_small];
                
                NSURL *url_big = [NSURL URLWithString:big];
                NSData *data_big = [[NSData alloc]initWithContentsOfURL:url_big];
                
                NSNumber *notLoaded = [NSNumber numberWithInt:0];
                
                [db executeUpdate: @"INSERT INTO Phoice(Section, IndexRow, Loaded, TextLabel, DetailDescription, SmallPhoto, SmallPhotoAddress, BigPhoto, BigPhotoAddress, AudioFile) VALUES (?,?,?,?,?,?,?,?,?,?);", nil, nil, notLoaded, nil, nil, data_small, small, data_big, big, nil ];
                
            }
        }
    }
    
    [db close];
}

-(void)obtainDataFromDB{
    //start off with initializing a plist file
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    Plist_filePath = [documentDirectory stringByAppendingPathComponent:@"image.plist"];
    BOOL success;
    
    if ([[NSFileManager defaultManager]fileExistsAtPath:Plist_filePath]){
        NSLog(@"Plist already created");
    }
    
    else{
        NSMutableArray *mainArray = [[NSMutableArray alloc]init];
        NSArray *array = [[NSArray alloc]initWithObjects:@"data_small", @"data_big", nil];
        [mainArray addObject:array];
        success = [mainArray writeToFile:Plist_filePath atomically:YES];
    }
    
    [db open];
    if ([db open]){
        FMResultSet *result = [db executeQuery:@"select * from Phoice"];
        while ([result next]){
            int loaded = [result intForColumn:@"Loaded"];
            if (!loaded){
                NSData *small_data = [result dataForColumn:@"SmallPhoto"];
                NSData *big_data = [result dataForColumn:@"BigPhoto"];
                NSArray *array = [[NSArray alloc]initWithObjects:small_data, big_data, nil];
                NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
                if(![mainArray containsObject:array]){
                    [mainArray addObject:array];
                    success = [mainArray writeToFile:Plist_filePath atomically:YES];
                    int currentRow = [result intForColumn:@"ID"];
                    
//                    NSString *updateSql = [NSString stringWithFormat:
//                                           @"UPDATE %@ SET %@ = %@ WHERE %@ = %@",
//                                           @"Phoice",  @"Loaded",  [NSNumber numberWithInt:1] ,@"ID",  [NSNumber numberWithInt:currentRow]];
//                    success = [db executeQuery:updateSql];
                    
                    
                    success = [db executeUpdate:@"UPDATE Phoice SET Loaded = ? WHERE ID = ?", [NSNumber numberWithInt:1], [NSNumber numberWithInt:currentRow]];
                    
                    FMResultSet *check = [db executeQuery:@"select * from Phoice where ID = ?", [NSNumber numberWithInt:currentRow]];
                    
                    int ans = [check intForColumn:@"Loaded"];
                    if (ans == 0){
                        NSLog(@"loaded is not changed");
                    }
                }
            }
            
        }
    }
    
    [db close];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(void)initializeView{
    //setup navigation bar
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
    self.navigationController.toolbar.barStyle = UIBarStyleBlackTranslucent;
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.toolbar.tintColor = [UIColor whiteColor];
    self.title = @"Phoice";
    
    
    
    //setup barItems
    flexItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    

    pickImage = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(chooseImage:)];
    //pickImage.tintColor = [UIColor redColor];
    self.navigationItem.rightBarButtonItem = pickImage;
    [self.navigationController setToolbarHidden:NO animated:YES];
    [self setToolbarItems:@[flexItem] animated:NO];
}

-(void)chooseImage: (UIBarButtonItem*) sender{
    imgPickerController = [[UIImagePickerController alloc]init];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]){
        imgPickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imgPickerController.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:imgPickerController.sourceType];
        
    }
    imgPickerController.delegate = self;
    imgPickerController.allowsEditing = NO;
    [self presentViewController:imgPickerController animated:YES completion:^(void){
        NSLog(@"going into photo library");
    }];
}

-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [self dismissViewControllerAnimated:YES completion:^(void){
        NSLog(@"user canceled action, going back to phoice");
    }];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
//    UIImage *chosenImg = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
//    NSString *description, *detail;
    
    NSLog(@"user selected something");
}


-(void) initializeTableView{
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.tblView = [[UITableView alloc] initWithFrame:CGRectMake(0, self.navigationController.navigationBar.frame.origin.y + self.navigationController.navigationBar.frame.size.height, self.view.frame.size.width, self.view.frame.size.height - self.navigationController.navigationBar.frame.size.height *2 - self.navigationController.navigationBar.frame.origin.y) style:UITableViewStylePlain];
    
    self.tblView.backgroundColor = [UIColor grayColor];
    
    self.tblView.dataSource = self;
    
    self.tblView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    self.tblView.separatorColor = [UIColor blackColor];
    
    self.tblView.allowsSelection = YES;
    self.tblView.userInteractionEnabled = YES;
    
    self.tblView.delegate = self;
    self.tblView.rowHeight = 100;

    
    [self.view addSubview:self.tblView];

}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.f;
}





-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return contentArray.count;
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    tableViewCell *cell = [_tblView cellForRowAtIndexPath:indexPath];
    
    int temp = (int)indexPath.row % contentArray.count;
    
    NSString *address = contentArray[temp];
    
    detailViewController *detail;

    detail = [[detailViewController alloc]initWithIndex:indexPath andAddress: address];
    detail.delegate = self;
    detail.photoLocation = cell.photoAddress;
    detail.audioLocation = cell.recordingAdress;
    
    [self.navigationController pushViewController:detail animated:YES];
    
    
    cell.selected = NO;
    
}


-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    
    NSString *reuseIdentifier = [NSString stringWithFormat:@"cellIdentifier:%ld %ld", (long)[indexPath section], (long)[indexPath row]];
    
    tableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    
    if (!cell){
        cell = [[tableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier: reuseIdentifier];
    }
    
    int index = (int)indexPath.row;
    int num = index % contentArray.count;
    
    NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
    NSArray *array = mainArray[num+1];
    NSData *small_data = array[0];
    
    UIImage *img = [[UIImage alloc]initWithData:small_data];
    cell.imageView.image = img;
    cell.imageView.tag = num;

//    NSString *str = contentArray[num];
//    NSURL *url = [NSURL URLWithString:str];
//    NSData *data = [[NSData alloc]initWithContentsOfURL:url];
//    UIImage*img = [[UIImage alloc]initWithData:data];
//    cell.imageView.image = img;
//    cell.imageView.tag = num;

    UITapGestureRecognizer *click = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(continuousView:)];
    click.numberOfTapsRequired = 1;
    cell.imageView.userInteractionEnabled = YES;
    //cell.imageView.multipleTouchEnabled = YES;
    [cell.imageView addGestureRecognizer:click];

    cell.textLabel.text = [NSString stringWithFormat:@"#%d", num];
    cell.detailTextLabel.text = contentArray[num];
    
    cell.photoAddress = contentArray[num];
    cell.recordingAdress = [self obtainCellRecordingAddressWithIndex: index];
    cell.tag = index;

    return cell;
}


-(NSString*) obtainCellRecordingAddressWithIndex: (int) index{
    NSString *string=[NSString stringWithFormat:@"num:%d.caf", index];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSFileManager *fileManage = [NSFileManager defaultManager];
    NSString *myDirectory = [documentDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%d", index]];
    [fileManage createDirectoryAtPath:myDirectory attributes:nil];
    NSString* filePath= [documentDirectory stringByAppendingPathComponent:string];
    
    return filePath;
}

//-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
//    UITableViewCell *cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
//
//      int index = (int)indexPath.row;
//      int num = index % contentArray.count;
////    int rand = arc4random_uniform((int)pathArray.count);
//
//    NSString *str = contentArray[num];
//    NSURL *url = [NSURL URLWithString:str];
//    NSData *data = [[NSData alloc]initWithContentsOfURL:url];
//    UIImage*img = [[UIImage alloc]initWithData:data];
//    cell.imageView.image = img;
//    cell.imageView.tag = num;
//    
//
//    UITapGestureRecognizer *click = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(continuousView:)];
//    click.numberOfTapsRequired = 1;
//    cell.imageView.userInteractionEnabled = YES;
//    //cell.imageView.multipleTouchEnabled = YES;
//    [cell.imageView addGestureRecognizer:click];
//    
//    
//    cell.textLabel.text = [NSString stringWithFormat:@"#%d", num];
//    
//    cell.detailTextLabel.text = contentArray[num];
//
//    return cell;
//}

-(void)initializePageControl{
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    
    pageControl = [[UIPageControl alloc]init];
    CGSize size = [pageControl sizeForNumberOfPages:contentArray.count];
    pageControl.numberOfPages = contentArray.count;
    pageControl.bounds = CGRectMake(0, 0, size.width, size.height);
    pageControl.center = CGPointMake(width *1.5, height -10);
    pageControl.pageIndicatorTintColor=[UIColor whiteColor];
    pageControl.currentPageIndicatorTintColor=[UIColor blueColor];
    
    [scrView addSubview: pageControl];
}

-(void) initiaizeScrollView{
    //setup the background scroll view
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    
    scrView = [[UIScrollView alloc]init];
    scrView.frame = [UIScreen mainScreen].bounds;
    scrView.frame = CGRectMake(0, 0, width+20, [UIScreen mainScreen].bounds.size.height);
    scrView.backgroundColor = [UIColor blackColor];
    //scrView.multipleTouchEnabled = YES;
    //scrView.maximumZoomScale = 2.0;
    scrView.delegate = self;
    scrView.userInteractionEnabled = YES;
    scrView.pagingEnabled = YES;
    scrView.contentSize = CGSizeMake(width * 3 +60 , scrView.bounds.size.height);
    [scrView setContentOffset:CGPointMake(width+20, 0) animated:YES];
    UITapGestureRecognizer *back = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(removeScrollView:)];
    back.numberOfTapsRequired = 1;
    [scrView addGestureRecognizer:back];

}

-(UIView*) viewForZoomingInScrollView:(UIScrollView *)scrollView{
    return (UIView*)imageView;
}

-(void)continuousView: (UITapGestureRecognizer*) tap{
    [self.navigationController setToolbarHidden:YES animated:YES];
    
    int index = (int)tap.view.tag;
    currentIndex = index;
    
    [self setupThreeImageViews];
    
    //scrView.backgroundColor = [UIColor blackColor];
    pageControl.currentPage = currentIndex;
    
    [self.view addSubview:scrView];
    
    imageView.hidden = YES;
    
//    imageView.userInteractionEnabled = YES;
//    imageView.multipleTouchEnabled = YES;
    
    
//    [UIView animateWithDuration:0.3 animations:^{
//        imageView.frame=CGRectMake(0,([UIScreen mainScreen].bounds.size.height-imgView.image.size.height*[UIScreen mainScreen].bounds.size.width/imgView.image.size.width)/2,
//                                   [UIScreen mainScreen].bounds.size.width,
//                                   imgView.image.size.height*[UIScreen mainScreen].bounds.size.width/imgView.image.size.width);
//        scrView.alpha=1;
//    } completion:^(BOOL finished) {
//    }];
    
        [UIView animateWithDuration:0.3 animations:^{
            scrView.backgroundColor = [UIColor blackColor];
            }
        completion:^(BOOL finished) {
            imageView.hidden = NO;
        }];
    
}

-(void)updateThreeImageViewsWithIndex: (int)index{
    int leftImageIndex, rightImageIndex;
    
    leftImageIndex = index - 1;
    if (index == 0)
        leftImageIndex = 5;
    
    rightImageIndex = index + 1;
    if (index == 5)
        rightImageIndex = 0;
    
    UIImage *leftImage = [UIImage new];
    UIImage *currentImage = [UIImage new];
    UIImage *rightImage = [UIImage new];
    
    leftImage = [self loadImageViewAtIndex:leftImageIndex];
    currentImage = [self loadImageViewAtIndex:index];
    rightImage = [self loadImageViewAtIndex:rightImageIndex];
    
    beforeView.image = leftImage;
    imageView.image = currentImage;
    afterView.image = rightImage;
    
}

-(void) setupThreeImageViews{
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    
    int beforeIndex, afterIndex;
    beforeIndex = currentIndex - 1;
    afterIndex = currentIndex + 1;
    
    if (currentIndex == 0){
        beforeIndex = 5;
    }
    
    else if(currentIndex == 5){
        afterIndex = 0;
    }
    
    
    beforeView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, width, height)];
    beforeView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *imageBefore = [self loadImageViewAtIndex:beforeIndex];
    beforeView.image = imageBefore;
    [scrView addSubview: beforeView];
    
    imageView = [[UIImageView alloc]initWithFrame:CGRectMake(width +20 , 0, width, height)];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *imageNow = [self loadImageViewAtIndex:currentIndex];
    imageView.image = imageNow;
    [scrView addSubview:imageView];
    
    afterView = [[UIImageView alloc]initWithFrame:CGRectMake(width*2 + 40 ,0,width, height)];
    afterView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *imageAfter = [self loadImageViewAtIndex:afterIndex];
    afterView.image = imageAfter;
    [scrView addSubview:afterView];
}

-(void) removeScrollView: (UITapGestureRecognizer*)tap{
    [UIView animateWithDuration:0.5 animations:^{
        //tap.view.backgroundColor = [UIColor clearColor];
        scrView.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
        [pageControl removeFromSuperview];
        [self.navigationController setToolbarHidden:NO animated:NO];
        [scrView removeFromSuperview];
        
        beforeView.image = nil;
        imageView.image = nil;
        afterView.image = nil;
        currentIndex = 9999;
        
        //[tap.view removeFromSuperview];
    }];
}

-(UIImage*)loadImageViewAtIndex:(int)index{
//    NSString *address = contentArray[index];
//    NSURL *url = [NSURL URLWithString:[address stringByReplacingOccurrencesOfString:@"thumbnail" withString:@"bmiddle"]];
//    NSData *data = [[NSData alloc]initWithContentsOfURL:url];
//    UIImage *img = [[UIImage alloc]initWithData:data];
    NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
    NSArray *arr = mainArray[index+1];
    NSData *data = arr[1];
    UIImage *img = [[UIImage alloc]initWithData:data];
    
    return img;
}



//-(void) scrollViewWillBeginDecelerating:(UIScrollView *)scrollView{
//    CGFloat width = [UIScreen mainScreen].bounds.size.width;
//    
//    CGPoint offset = [scrView contentOffset];
//    
//    int index;
//    
//    if(offset.x > width * 1.5){
//        if (currentIndex == 5)
//            index = 0;
//        else
//            index = currentIndex + 1;
//        
//        [self updateThreeImageViewsWithIndex:index];
//        currentIndex = index;
//    }
//    
//    else if (offset.x < width * 0.5){
//        if (currentIndex == 0)
//            index = 5;
//        else
//            index = currentIndex - 1;
//        
//        [self updateThreeImageViewsWithIndex:index];
//        currentIndex = index;
//    }
//    
//    pageControl.currentPage = currentIndex;
//    [scrView setContentOffset:CGPointMake(width, 0) animated:YES];
////    scrView.contentOffset = CGPointMake(width, 0);
//}



-(void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    
    CGPoint offset = [scrView contentOffset];
    
    int index;
    
    if(offset.x > width * 1.5){
        if (currentIndex == 5)
            index = 0;
        else
            index = currentIndex + 1;
        
        [self updateThreeImageViewsWithIndex:index];
        currentIndex = index;
    }
    
    else if (offset.x < width * 0.5){
        if (currentIndex == 0)
            index = 5;
        else
            index = currentIndex - 1;
        
        [self updateThreeImageViewsWithIndex:index];
        currentIndex = index;
    }
    
    pageControl.currentPage = currentIndex;
    [scrView setContentOffset:CGPointMake(width+20, 0) animated:NO];
// scrView.contentOffset = CGPointMake(width, 0);

}


//- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
//    CGPoint offset = [scrView contentOffset];
//    
//    if (offset.x > [UIScreen mainScreen].bounds.size.width){
//        int index = currentIndex + 1;
//        if (index > 5) index = 0;
//        
//        [imgView removeFromSuperview];
//        [self loadImageViewAtIndex:index];
//    }
//    
//    else if (offset.x < [UIScreen mainScreen].bounds.size.width){
//        int index = currentIndex - 1;
//        if (index < 0) index = 5;
//        
//        [imgView removeFromSuperview];
//        [self loadImageViewAtIndex:index];
//    }
//}



-(void)changeCellInfoWithText:(NSString *)string andDetailInfo:(NSString *)detail onIndexPath:(NSIndexPath *)indexpath{
    UITableViewCell *cell = [self.tblView cellForRowAtIndexPath:indexpath];
    
    cell.textLabel.text = string;
    cell.detailTextLabel.text = detail;
}


@end