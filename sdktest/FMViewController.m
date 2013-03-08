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
    FMSession *session = [FMSession sessionWithClientToken:@"Token" secret:@"Secret"];
    [session requestStationsForPlacement:@"Placement"];
}

- (void)session:(FMSession *)session didReceiveStations:(NSArray *)stations {
    if([stations count] > 0) {
        [session setStation:stations[0]];
        self.feedPlayer = [FMAudioPlayer playerWithSession:session];
        [self.feedPlayer play];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
