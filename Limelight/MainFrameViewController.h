//
//  MainFrameViewController.h
//  Limelight-iOS
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Diego Waxemberg. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MDNSManager.h"
#import "PairManager.h"

@interface MainFrameViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate, MDNSCallback, NSURLConnectionDelegate, PairCallback>
@property (strong, nonatomic) IBOutlet UIPickerView *HostPicker;
- (IBAction)StreamButton:(UIButton *)sender;
- (IBAction)PairButton:(UIButton *)sender;

@property (strong, nonatomic) IBOutlet UIPickerView *StreamConfigs;
@property (strong, nonatomic) NSArray* streamConfigVals;
@property (strong, nonatomic) NSArray* hostPickerVals;

+ (int) getResolvedHost;
+ (NSData*) getRiKey;
+ (int) getRiKeyId;

- (void) segueIntoStream;

@end
