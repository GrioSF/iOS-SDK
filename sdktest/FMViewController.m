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
#import "FMAudioItem.h"
#import "FMProgressView.h"

#define kFMSessionClientToken @"e518c7bb995c28ea12deb8ddc9b6458c41005f56"
#define kFMSessionClientSecret @"512cac1423f76a4b25235fa0afb092013b68f7d8"
#define kFMSessionPlacementId @"10002"

#define kFMProgressBarUpdateTimeInterval 0.5
#define kFMProgressBarHeight 5.0f

@interface FMViewController () {
    NSTimer *_progressTimer;
}

@property IBOutlet UILabel *currentStationLabel;
@property IBOutlet UIView *playerContainer;
@property FMProgressView *progressView;
@property IBOutlet UILabel *songLabel;
@property IBOutlet UILabel *artistLabel;
@property IBOutlet UIButton *playButton;
@property IBOutlet UIButton *skipButton;
@property UIActivityIndicatorView *playButtonSpinner;

- (IBAction)selectStation:(id)sender;
- (IBAction)play:(id)sender;
- (IBAction)skip:(id)sender;
- (IBAction)setVolume:(id)sender;

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

    self.progressView = [[FMProgressView alloc] initWithFrame:CGRectMake(0,
                                                                         self.playerContainer.bounds.size.height - kFMProgressBarHeight,
                                                                         self.playerContainer.bounds.size.width,
                                                                         kFMProgressBarHeight)];
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    [self.playerContainer addSubview:self.progressView];

    [FMSession setClientToken:kFMSessionClientToken
                       secret:kFMSessionClientSecret];
    [[FMSession sharedSession] setPlacement:kFMSessionPlacementId];
    NSLog(@"Set placement: %@", [FMSession sharedSession].activePlacementId);
    [[FMSession sharedSession] setDelegate:self];
    self.feedPlayer = [[FMAudioPlayer alloc] initWithSession:[FMSession sharedSession]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stationUpdated:) name:FMSessionActiveStationChangedNotification object:[FMSession sharedSession]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerUpdated:) name:FMAudioPlayerPlaybackStateDidChangeNotification object:self.feedPlayer];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self cancelProgressTimer];
}

- (void)stationUpdated:(NSNotification *)notification {
    self.currentStationLabel.text = [FMSession sharedSession].activeStation.name;
}

- (void)selectStation:(id)sender {
    [self.navigationController pushViewController:[[FMStationPickerViewController alloc] init] animated:YES];
}

- (void)playerUpdated:(NSNotification *)notification {
    FMAudioPlayerPlaybackState newState = self.feedPlayer.playbackState;
    NSLog(@"Got playback state: %i", newState);
    switch(newState) {
        case FMAudioPlayerPlaybackStateWaitingForItem:
            [self showPlayButtonSpinner];
            [self.skipButton setEnabled:NO];
            break;
//        case FMAudioPlayerPlaybackStateNewItem:
//            NSLog(@"Got New Item Notification");
//            [self hidePlayButtonSpinner];
//            [self.skipButton setEnabled:NO];
//            //FIXME: should listen to skipLimitKnown property of player or similar to set enabled, right now the button is enabled during a period when the player isn't sure if it can skip
//            [self.progressView setProgress:0.0];
//            [self updateLabels];
//            break;
        case FMAudioPlayerPlaybackStateReadyToPlay:
        case FMAudioPlayerPlaybackStatePaused:
            [self hidePlayButtonSpinner];
            [self.skipButton setEnabled:YES];
            [self.playButton setEnabled:YES];
            [self.playButton setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
            [self cancelProgressTimer];
            break;
        case FMAudioPlayerPlaybackStatePlaying:
            [self hidePlayButtonSpinner];
            [self updateLabels];
            [self.playButton setImage:[UIImage imageNamed:@"pause.png"] forState:UIControlStateNormal];
            [self.playButton setEnabled:YES];
            [self.skipButton setEnabled:YES];
            [self startProgressTimer];
            break;
        case FMAudioPlayerPlaybackStateRequestingSkip:
            [self showPlayButtonSpinner];
            [self.playButton setEnabled:NO];
            [self.skipButton setEnabled:NO];
        case FMAudioPlayerPlaybackStateComplete:
            [self updateLabels];
            [self.playButton setEnabled:NO];
            [self.skipButton setEnabled:NO];
            [self cancelProgressTimer];
            [self.progressView setProgress:0.0];
            break;
        default:
            break;
    };
}

- (void)updateLabels {
    self.songLabel.text = self.feedPlayer.session.currentItem.name;
    self.artistLabel.text = self.feedPlayer.session.currentItem.artist;
}

- (void)setVolume:(id)sender {
    assert([sender isKindOfClass:[UISlider class]]);
    self.feedPlayer.mixVolume = [(UISlider *)sender value];
}

#pragma mark - Player Button States


- (void)play:(id)sender {
    if(self.feedPlayer.playbackState == FMAudioPlayerPlaybackStatePlaying) {
        [self.feedPlayer pause];
    } else {
        [self.feedPlayer play];
    }
}

- (void)skip:(id)sender {
    if(self.feedPlayer.session.skipAvailable) {
        [self.feedPlayer skip];
    }
    else {  //todo: make sure this doesn't get triggered when we don't know the skip limit yet
        UIAlertView *noSkipAlert = [[UIAlertView alloc] initWithTitle:@"No More Skips" message:@"Sorry, you‘ve reached your skip limit for this station. Skips will replenish over time." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [noSkipAlert show];
    }
}

- (void)showPlayButtonSpinner {
    if([self.playButtonSpinner superview]) return;

    self.playButtonSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.playButtonSpinner.frame = self.playButton.frame;
    [[self.playButton superview] addSubview:self.playButtonSpinner];
    [self.playButton setHidden:YES];
    [self.playButtonSpinner startAnimating];
}

- (void)hidePlayButtonSpinner {
    [self.playButtonSpinner stopAnimating];
    [self.playButtonSpinner removeFromSuperview];
    self.playButtonSpinner = nil;
    [self.playButton setHidden:NO];
}

#pragma mark - Progress Bar
- (void)cancelProgressTimer {
    [_progressTimer invalidate];
    _progressTimer = nil;
}

- (void)startProgressTimer {
    [_progressTimer invalidate];
    _progressTimer = [NSTimer scheduledTimerWithTimeInterval:kFMProgressBarUpdateTimeInterval
                                                     target:self
                                                   selector:@selector(updateProgress:)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)updateProgress:(NSTimer *)timer {
    NSTimeInterval duration = self.feedPlayer.currentItemDuration;
    if(duration > 0) {
        self.progressView.progress = (self.feedPlayer.currentPlaybackTime / duration);
    }
    else {
        self.progressView.progress = 0.0;
    }
}

@end

#undef kFMProgressBarUpdateTimeInterval
#undef kFMSessionClientToken
#undef kFMSessionClientSecret
#undef kFMSessionPlacementId
