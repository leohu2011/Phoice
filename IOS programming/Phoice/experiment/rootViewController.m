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
#import "MWPhotoBrowser.h"

@interface rootViewController()<UIImagePickerControllerDelegate, UINavigationControllerDelegate, MWPhotoBrowserDelegate>

@end

@implementation rootViewController{
    NSArray *contentArray;
    UIScrollView *scrView;
    UIImageView *imageView;
    UIImageView *beforeView;
    UIImageView *afterView;
    int currentIndex;
    UIPageControl *pageControl;
//    NSIndexPath *currentIndexPath;
    
    NSInteger numberOfItems;
    
    UIImagePickerController *imgPickerController;
    UIBarButtonItem *pickImage;
    UIBarButtonItem *flexItem;
    
    //MWPhotoArray
    NSMutableArray *mwPhotoArray;
    
    //database
    NSString *dbPath;
    FMDatabase *db;
    
    //local cache storage containing the two nsdata for two images
    //each array element contains: <small_data, big_data, small_address/assetURL>
    NSString *Plist_filePath;
    //array containing description and detail, NOTICE that this array much match one-to-one to that of the array in the above Plist
    NSMutableArray *cellInfoArray;
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
    
    [self loadIntoMWPhotoArray];
    
    [self initializeView];
    
    [self initializeTableView];
    
//    [self initiaizeScrollView];
//    
//    [self initializePageControl];

}

-(void)loadIntoMWPhotoArray{
    mwPhotoArray = [[NSMutableArray alloc]init];
    
    NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
    [mainArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if([obj[1] isKindOfClass:[NSData class]]){
            UIImage *img = [[UIImage alloc]initWithData:obj[1]];
            [mwPhotoArray addObject:[MWPhoto photoWithImage:img]];
        }
    }];
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
        NSArray *array = [[NSArray alloc]initWithObjects:@"data_small", @"data_big", @"small_address", nil];
        NSMutableArray *mainArray = [[NSMutableArray alloc]init];
        [mainArray addObject:array];
        success = [mainArray writeToFile:Plist_filePath atomically:YES];
    }
    
    if ([db open]){

        FMResultSet *result = [db executeQuery:@"select * from Phoice"];
        
        //beginTransaction to make sure that the update is not done in a one-to-one manner, but altogether
        success = [db beginTransaction];
        
        while ([result next]){
            int loaded = [result intForColumn:@"Loaded"];
            if (!loaded){
                NSData *small_data = [result dataForColumn:@"SmallPhoto"];
                NSData *big_data = [result dataForColumn:@"BigPhoto"];
                NSString *small_address = [result stringForColumn:@"SmallPhotoAddress"];
                NSArray *array = [[NSArray alloc]initWithObjects:small_data, big_data, small_address, nil];
                NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
                [mainArray addObject:array];
                success = [mainArray writeToFile:Plist_filePath atomically:YES];
                int currentRow = [result intForColumn:@"ID"];
                
                NSString *updateSql = [NSString stringWithFormat:
                                       @"UPDATE %@ SET %@ = %@ WHERE %@ = %@",
                                       @"Phoice",  @"Loaded",  [NSNumber numberWithInt:1] ,@"ID",  [NSNumber numberWithInt:currentRow]];
                
                success = [db executeUpdate:updateSql];
                }
            }
        [db commit];
        }
    [db close];
    
    NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
    numberOfItems = mainArray.count - 1;
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
    self.navigationController.toolbar.tintColor = [UIColor blackColor];
    self.title = @"Phoice";
    
    
    
    //setup barItems
    flexItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    

    pickImage = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(chooseImage:)];
    //pickImage.tintColor = [UIColor redColor];
    self.navigationItem.rightBarButtonItem = pickImage;
    [self.navigationController setToolbarHidden:NO animated:YES];
    //[self setToolbarItems:@[flexItem] animated:NO];
}

-(void)chooseImage: (UIBarButtonItem*) sender{
    imgPickerController = [[UIImagePickerController alloc]init];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]){
        imgPickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imgPickerController.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:imgPickerController.sourceType];
        
    }
    imgPickerController.delegate = self;
    imgPickerController.allowsEditing = NO;
    
//    [self performSelector:@selector(gotoImagePicker) withObject:nil afterDelay:0.5f];
    
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
    UIImage *chosenImg = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    NSURL *small_url = [info objectForKey:@"UIImagePickerControllerReferenceURL"];
    NSString *small_address = [small_url absoluteString];
    
    NSData *big_data = UIImagePNGRepresentation(chosenImg);
    NSData *small_data = UIImageJPEGRepresentation(chosenImg, 0.5);
    
    //saving and updating
    NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
    NSArray *array = [[NSArray alloc]initWithObjects:small_data, big_data, small_address, nil];
    BOOL contain = NO;
    
    for (NSArray *arr in mainArray){
        if ([arr[2] isEqualToString:small_address]){
            contain = YES;
            break;
        }
    }
    
    //alert if the user is selecting the same photo to incorporate
    if (contain){
        //tell the user to try again
        UIAlertController *repeatSelection = [UIAlertController alertControllerWithTitle:@"This is an Alert" message:@"repeated selection" preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
        
        [repeatSelection addAction:cancel];
        
        [picker presentViewController:repeatSelection animated:YES completion:nil]; 
    }

    
    //prompt the user to enter these two fields
    __block NSString *description, *detail;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"This is an Alert" message:@"Input Photo Info" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * textField){
        textField.placeholder = @"textLabel";
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * textField){
        textField.placeholder = @"detailInfo";
    }];
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act){
        
        UITextField *text1 = alert.textFields.firstObject;
        UITextField *text2 = alert.textFields.lastObject;
        description = text1.text;
        detail = text2.text;
        

        
        if(!contain){
            //put into the mwPhotoArray
            UIImage *img = [[UIImage alloc]initWithData:big_data];
            [mwPhotoArray addObject:[MWPhoto photoWithImage:img]];
            //save onto plist
            [mainArray addObject:array];
            BOOL success = [mainArray writeToFile:Plist_filePath atomically:YES];
            if (!success){
                NSLog(@"failure writing new item onto Plist");
            }
            
            //update FMDB
            if ([db open]){
                [db beginTransaction];
                
                if (description == nil) description = @"from user Library";
                if (detail == nil) description = @"from user Library";
                
                [db executeUpdate:@"INSERT INTO Phoice(Section, IndexRow, Loaded, TextLabel, DetailDescription, SmallPhoto, SmallPhotoAddress, BigPhoto, BigPhotoAddress, AudioFile) VALUES (?,?,?,?,?,?,?,?,?,?);", nil, nil, [NSNumber numberWithInteger:1], nil, nil, small_data, description, big_data, detail, nil ];
                
                [db commit];
            }
        }
        
        [db close];
        
        //back to Phoice
        [self dismissViewControllerAnimated:YES completion:^(void){
            NSLog(@"user selected something");
        }];
        
        //on completion need to reload the tableView
        numberOfItems += 1;
        [self.tblView reloadData];
    }];
    UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:action];
    [alert addAction:action2];
    
    [picker presentViewController:alert animated:YES completion:nil];
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
    return 0.f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.f;
}





-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return numberOfItems;
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    tableViewCell *cell = [_tblView cellForRowAtIndexPath:indexPath];
    
    int temp = (int)indexPath.row % numberOfItems;
    
//    NSString *address = contentArray[temp];
    NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
    int num = temp % numberOfItems;
    NSString *address = mainArray[num][2];
    
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
    int num = index % numberOfItems;
    
    NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
    //here is num + 1 because the first object in mainArray is the default small_data/big_data
    //will consider scrapping that for simplicity
    NSArray *array = mainArray[num + 1];
    NSData *small_data = array[0];
    
    UIImage *img = [[UIImage alloc]initWithData:small_data];
    cell.imageView.image = img;
    cell.imageView.tag = num;

    UITapGestureRecognizer *click = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(continuousView:)];
    click.numberOfTapsRequired = 1;
    cell.imageView.userInteractionEnabled = YES;
    //cell.imageView.multipleTouchEnabled = YES;
    [cell.imageView addGestureRecognizer:click];

    cell.textLabel.text = [NSString stringWithFormat:@"#%d", num];
    cell.detailTextLabel.text = array[2];
    
    cell.photoAddress = array[2];
    cell.recordingAdress = [self obtainCellRecordingAddressWithIndex: index];
    cell.tag = index;

    return cell;
}

-(void)continuousView: (UITapGestureRecognizer*)tap{
    //go to MW Photo Array
    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc]initWithDelegate:self];
    
    browser.displayActionButton = YES; // Show action button to allow sharing, copying, etc (defaults to YES)
    browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
    browser.displaySelectionButtons = NO; // Whether selection buttons are shown on each image (defaults to NO)
    browser.zoomPhotosToFill = YES; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
    browser.alwaysShowControls = NO; // Allows to control whether the bars and controls are always visible or whether they fade away to show the photo full (defaults to NO)
    browser.enableGrid = YES; // Whether to allow the viewing of all the photo thumbnails on a grid (defaults to YES)
    browser.startOnGrid = NO; // Whether to start on the grid of thumbnails instead of the first photo (defaults to NO)
    
    int index = (int)tap.view.tag;
    currentIndex = index;
    [browser setCurrentPhotoIndex:currentIndex];
    
    [self.navigationController pushViewController:browser animated:YES];
    
    [browser showNextPhotoAnimated:YES];
    [browser showPreviousPhotoAnimated:YES];
}

- (id<MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if(index < mwPhotoArray.count){
        return [mwPhotoArray objectAtIndex:index];
    }
    
    return nil;
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return mwPhotoArray.count;
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


/*
-(void)initializePageControl{
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    
    pageControl = [[UIPageControl alloc]init];
    CGSize size = [pageControl sizeForNumberOfPages:numberOfItems];
    pageControl.numberOfPages = numberOfItems;
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
//    scrView.multipleTouchEnabled = YES;
//    scrView.maximumZoomScale = 2.0;
//    scrView.minimumZoomScale = 0.5;
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
        leftImageIndex = (int)numberOfItems-1;
    
    rightImageIndex = index + 1;
    if (index == numberOfItems-1)
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
        beforeIndex = (int)numberOfItems-1;
    }
    
    else if(currentIndex == numberOfItems-1){
        afterIndex = 0;
    }
    
    
    beforeView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, width, height)];
    beforeView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *imageBefore = [self loadImageViewAtIndex:beforeIndex];
    beforeView.image = imageBefore;
//    beforeView.userInteractionEnabled = YES;
//    beforeView.multipleTouchEnabled = YES;
    [scrView addSubview: beforeView];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc]initWithTarget:self action:@selector(zoomImage:)];
//    pinch.delegate = self;
    imageView = [[UIImageView alloc]initWithFrame:CGRectMake(width +20 , 0, width, height)];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *imageNow = [self loadImageViewAtIndex:currentIndex];
    imageView.image = imageNow;
    imageView.userInteractionEnabled = YES;
    imageView.multipleTouchEnabled = YES;
    [imageView addGestureRecognizer:pinch];
    [scrView addSubview:imageView];
    
    afterView = [[UIImageView alloc]initWithFrame:CGRectMake(width*2 + 40 ,0,width, height)];
    afterView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *imageAfter = [self loadImageViewAtIndex:afterIndex];
    afterView.image = imageAfter;
//    afterView.userInteractionEnabled = YES;
//    afterView.multipleTouchEnabled = YES;
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
//        currentIndex = 9999;
    }];
}

-(void)zoomImage: (UIPinchGestureRecognizer*)recognizer{
    CGFloat scale = recognizer.scale;
    [self setScale: scale];
    
}

-(void)setScale: (CGFloat)scale{
    if (scale < 0.5  || scale > 2.0) return; // 最大缩放 2倍,最小0.5倍
    
    imageView.transform = CGAffineTransformMakeScale(scale, scale);
    
    if(scale > 1){
        CGFloat contentW = imageView.frame.size.width;
        CGFloat contentH = MAX(imageView.frame.size.height, [UIScreen mainScreen].bounds.size.height);
        
        imageView.center = CGPointMake(contentW * 0.5, contentH * 0.5);
        scrView.contentSize = CGSizeMake(contentW, contentH);
        
        
        CGPoint offset = scrView.contentOffset;
        offset.x = (contentW - scrView.frame.size.width) * 0.5;
        //        offset.y = (contentH - _zoomingImageView.frame.size.height) * 0.5;
        scrView.contentOffset = offset;
        
    }
    else {
        scrView.contentSize = scrView.frame.size;
        scrView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
        imageView.center = scrView.center;
    }
}

-(UIImage*)loadImageViewAtIndex:(int)index{
    NSMutableArray *mainArray = [[NSMutableArray alloc]initWithContentsOfFile:Plist_filePath];
    NSArray *arr = mainArray[index+1];
    NSData *data = arr[1];
    UIImage *img = [[UIImage alloc]initWithData:data];
    
    return img;
}


//need to account for two scenarios -- 1.the imageView is smaller than the frame of the screen; 2.the ImageView is larger than the frame of the screen
-(void) scrollViewDidZoom:(UIScrollView *)scrollView{

}

-(void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    
    CGPoint offset = [scrView contentOffset];
    
    int index;
    
    if(offset.x > width * 1.5){
        if (currentIndex == numberOfItems - 1)
            index = 0;
        else
            index = currentIndex + 1;
        
        [self updateThreeImageViewsWithIndex:index];
        currentIndex = index;
    }
    
    else if (offset.x < width * 0.5){
        if (currentIndex == 0)
            index = (int)numberOfItems - 1;
        else
            index = currentIndex - 1;
        
        [self updateThreeImageViewsWithIndex:index];
        currentIndex = index;
    }
    
    pageControl.currentPage = currentIndex;
    [scrView setContentOffset:CGPointMake(width+20, 0) animated:NO];

}
*/


-(void)changeCellInfoWithText:(NSString *)string andDetailInfo:(NSString *)detail onIndexPath:(NSIndexPath *)indexpath{
    UITableViewCell *cell = [self.tblView cellForRowAtIndexPath:indexpath];
    
    cell.textLabel.text = string;
    cell.detailTextLabel.text = detail;
}


@end