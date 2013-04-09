//
//  FMViewController.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMSession.h"
#import "FMAudioPlayer.h"

@interface FMViewController : UIViewController <FMSessionDelegate>

@property FMAudioPlayer *feedPlayer;
@property IBOutlet UILabel *currentStationLabel;

- (IBAction)selectStation:(id)sender;

@end
