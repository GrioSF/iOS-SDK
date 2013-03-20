//
//  FMViewController.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMViewController.h"
#import "FMAudioPlayer.h"

@interface FMViewController ()

@end

@implementation FMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [FMSession setClientToken:@"e518c7bb995c28ea12deb8ddc9b6458c41005f56" secret:@"512cac1423f76a4b25235fa0afb092013b68f7d8"];
    [[FMSession sharedSession] setPlacement:@"10002"];
    [[FMSession sharedSession] setDelegate:self];
    [[FMSession sharedSession] requestStations];
}

- (void)session:(FMSession *)session didReceiveStations:(NSArray *)stations {
    NSLog(@"Got stations: %@",stations);
    if([stations count] > 0) {
        [session setStation:stations[0]];
        //self.feedPlayer = [FMAudioPlayer playerWithSession:session];
        //[self.feedPlayer play];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
