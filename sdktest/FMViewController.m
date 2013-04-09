//
//  FMViewController.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMViewController.h"
#import "FMAudioPlayer.h"
#import "FMStationPickerViewController.h"
#import "FMStation.h"

#define kFMSessionClientToken @"e518c7bb995c28ea12deb8ddc9b6458c41005f56"
#define kFMSessionClientSecret @"512cac1423f76a4b25235fa0afb092013b68f7d8"
#define kFMSessionPlacementId @"10002"

@interface FMViewController ()

@end

@implementation FMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Feed Media SDK Demo";
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action:nil];

    [FMSession setClientToken:kFMSessionClientToken
                       secret:kFMSessionClientSecret];
    [[FMSession sharedSession] setPlacement:kFMSessionPlacementId];
    [[FMSession sharedSession] setDelegate:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stationUpdated:) name:FMSessionActiveStationChangedNotification object:[FMSession sharedSession]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)stationUpdated:(NSNotification *)notification {
    self.currentStationLabel.text = [FMSession sharedSession].activeStation.name;
}

- (void)selectStation:(id)sender {
    [self.navigationController pushViewController:[[FMStationPickerViewController alloc] init] animated:YES];
}


@end

#undef kFMSessionClientToken
#undef kFMSessionClientSecret
#undef kFMSessionPlacementId
