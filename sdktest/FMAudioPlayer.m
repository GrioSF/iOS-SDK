//
//  FMAudioPlayer.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//  Contains code copyright (c) 2011 Apple Inc. from the sample code StitchedStreamPlayer
//

#import "FMAudioPlayer.h"
#import "FMSession.h"
#import "FMAudioItem.h"
#import <AVFoundation/AVFoundation.h>

static void *FMAudioPlayerRateObservationContext = &FMAudioPlayerRateObservationContext;
static void *FMAudioPlayerCurrentItemObservationContext = &FMAudioPlayerCurrentItemObservationContext;
static void *FMAudioPlayerPlayerItemStatusObserverContext = &FMAudioPlayerPlayerItemStatusObserverContext;

NSString *const FMAudioPlayerPlaybackStateDidChangeNotification = @"FMAudioPlayerPlaybackStateDidChangeNotification";

#define kTracksKey @"tracks"
#define kStatusKey @"status"
#define kRateKey @"rate"
#define kPlayableKey @"playable"
#define kCurrentItemKey	@"currentItem"

@interface FMAudioPlayer () {
    AVQueuePlayer *_player;
    BOOL _isClientPaused;
    BOOL _isInternalPaused;
    BOOL _playImmediately;
}
@property (nonatomic) FMAudioPlayerPlaybackState playbackState;
@end

@implementation FMAudioPlayer

+ (FMAudioPlayer *)playerWithSession:(FMSession *)session {
    return [[FMAudioPlayer alloc] initWithSession:session];
}

- (id)initWithSession:(FMSession *)session {
    if(self = [super init]) {
        self.session = session;
        _mixVolume = 1.0;
        _playbackState = FMAudioPlayerPlaybackStateWaitingForItem;
        _player = [[AVQueuePlayer alloc] init];
        _player.actionAtItemEnd = AVPlayerActionAtItemEndAdvance;
        [_player addObserver:self
                  forKeyPath:kCurrentItemKey
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:FMAudioPlayerCurrentItemObservationContext];
        [_player addObserver:self
                  forKeyPath:kRateKey
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:FMAudioPlayerRateObservationContext];

    }
    return self;
}

- (void)dealloc {
    [_player removeObserver:self forKeyPath:kCurrentItemKey];
    [_player removeObserver:self forKeyPath:kRateKey];
}

#pragma mark - Passthrough Properties

- (NSTimeInterval)currentPlaybackTime {
    CMTime playbackTime = [_player currentTime];
    return CMTimeGetSeconds(playbackTime);
    
}
- (NSTimeInterval)currentItemDuration {
    AVPlayerItem *currentItem = [_player currentItem];
    if(currentItem.status == AVPlayerItemStatusReadyToPlay) {
        return CMTimeGetSeconds(currentItem.duration);
    }
    else {
        return self.session.currentItem.duration;
    }
}

- (float) currentPlaybackRate {
    return _player.rate;
}

//todo: beef up with internal ability to play, or is this good enough?
- (BOOL) isPreparedToPlay {
    return (_player.currentItem.status == AVPlayerItemStatusReadyToPlay) &&
            (self.playbackState != FMAudioPlayerPlaybackStateWaitingForItem);
}

#pragma mark - Audio Mixing

- (void)applyMixVolumeToItem:(AVPlayerItem *)playerItem {
    AVAsset *asset = playerItem.asset;
    NSMutableArray *allAudioParams = [NSMutableArray array];
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    for(AVAssetTrack *track in audioTracks) {
        AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
        [audioInputParams setVolume:self.mixVolume atTime:kCMTimeZero];
        [audioInputParams setTrackID:track.trackID];
        [allAudioParams addObject:audioInputParams];
    }
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    [audioMix setInputParameters:allAudioParams];
    [playerItem setAudioMix:audioMix];
}

- (void)setMixVolume:(float)mixVolume {
    _mixVolume = MIN(MAX(0.0f,mixVolume),1.0f);
    for(AVPlayerItem *playerItem in [_player items]) {
        [self applyMixVolumeToItem:playerItem];
    }
}

#pragma mark - Item Handling

- (void)prepareToPlay {
    NSLog(@"Prepare To Play");
    if([_player.items count] > 1) {
        NSLog(@"Already have items, ignoring");
        //already have a playing item, no need for additional preparation
        return;
    }
    if(self.playbackState == FMAudioPlayerPlaybackStateWaitingForItem) {
        NSLog(@"Already waiting for item, ignoring");
        //already requested an item, keep waiting
        return;
    }
    if(!self.session.nextItem) {
        NSLog(@"Requesting item");
        //todo: make sure we actually have a session, and that session has a placement/station/etc
        [self.session requestNextTrack];
        return;
    }
}

- (void)sessionReceivedItem {
    NSLog(@"Session Received Item");
    if(self.session.nextItem) {
        NSURL *itemUrl = self.session.nextItem.contentUrl;
        //todo: write guard against nil url
        NSLog(@"Requesting asset for %@",itemUrl);
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:itemUrl options:nil];
        NSArray *requestedKeys = [NSArray arrayWithObjects:kTracksKey, kPlayableKey, nil];

        /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
        [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
         ^{
             dispatch_async( dispatch_get_main_queue(),
                            ^{
                                /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
                                [self prepareToPlayAsset:asset withKeys:requestedKeys];
                            });
         }];
    }
}

-(void)assetFailedToPrepareForPlayback:(NSError *)error {
    NSLog(@"Asset failed to prepare: %@", error);
    //todo: cleanup
    //todo: throw error
    //todo: attempt to reload/load next asset
}

- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys {
    NSLog(@"Prepare to play asset");
    /* Make sure that the value of each key has loaded successfully. */
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
			[self assetFailedToPrepareForPlayback:error];
			return;
		}
		/* If you are also implementing the use of -[AVAsset cancelLoading], add your code here to bail
         out properly in the case of cancellation. */
	}

    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable)
    {
        /* Generate an error describing the failure. */
        //todo: rewrite into our own error codes
		NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
		NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
		NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
								   localizedDescription, NSLocalizedDescriptionKey,
								   localizedFailureReason, NSLocalizedFailureReasonErrorKey,
								   nil];
		NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];

        /* Display the error to the user. */
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];

        return;
    }

    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    AVPlayerItem *nextItem = [AVPlayerItem playerItemWithAsset:asset];

    [self registerForPlayerItemNotifications:nextItem];
    [self applyMixVolumeToItem:nextItem];

    /* Make our new AVPlayerItem the AVPlayer's current item. */
    [_player insertItem:nextItem afterItem:nil];
    NSLog(@"Added item to queue");

    //If we want to try prerolling, delete teh above block and put all this into effect AFTER readyToPlay KVO is triggered
//    if([_player.items count] == 1) {
//        NSLog(@"Requesting preroll");
//        [_player prerollAtRate:1.0 completionHandler:^(BOOL finished) {
//            if(finished) {
//                NSLog(@"Preroll Success");
//                [self setPlaybackState:FMAudioPlayerPlaybackStateReadyToPlay];
//                if(_playImmediately) {
//                    NSLog(@"Playing immediately");
//                    [self play];
//                }
//            }
//            else {
//                NSLog(@"Preroll Failed");
//                //todo: how bad is this error? how to recover?
//            }
//        }];
//    }
}

#pragma mark - Player Item Notifications

- (void)registerForPlayerItemNotifications:(AVPlayerItem *)item {
    /* Observe the player item "status" key to determine when it is ready to play. */
    [item addObserver:self
               forKeyPath:kStatusKey
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:FMAudioPlayerPlayerItemStatusObserverContext];

    /* Register to be notified when the item completes */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemFailedToReachEnd:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:item];
    if(&AVPlayerItemPlaybackStalledNotification) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemStalled:)
                                                     name:AVPlayerItemPlaybackStalledNotification
                                                   object:item];
    }
}

- (void)unregisterForPlayerItemNotifications:(AVPlayerItem *)item {
    [item removeObserver:self forKeyPath:kStatusKey];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:item];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:item];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playerItemDidReachEnd:notification];
        });
        return;
    }
    NSLog(@"Item reached end");
    [self unregisterForPlayerItemNotifications:notification.object];
    [self.session playCompleted];
    self.playbackState = FMAudioPlayerPlaybackStateComplete;
    if([_player.items count] < 2) {
        NSLog(@"Player Queue empty, preparing to play a new one");
        [self prepareToPlay];
        [self setPlaybackState: FMAudioPlayerPlaybackStateWaitingForItem];
    }
}

- (void)playerItemFailedToReachEnd:(NSNotification *)notification {
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playerItemFailedToReachEnd:notification];
        });
        return;
    }

    [self unregisterForPlayerItemNotifications:notification.object];
    NSLog(@"Item failed to reach end: %@", notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey]);
    //todo: recover!
}

- (void)playerItemStalled:(NSNotification *)notification {
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playerItemStalled:notification];
        });
        return;
    }
    NSLog(@"Stalled");
    [self setPlaybackState:FMAudioPlayerPlaybackStateStalled];
    //todo: try to recover from stall
    //todo: check if this is equivalent to existing iOS 5 tests for stalled-ness
}

#pragma mark - State Handling

//todo: are these the proper actions to take?
//todo: do we need to use the currentItemChanged notification to check for skip success?
- (void)setSession:(FMSession *)session {
    if(_session) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:FMSessionNextItemAvailableNotification object:_session];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:FMSessionActivePlacementChangedNotification object:_session];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:FMSessionActiveStationChangedNotification object:_session];
    }
    _session = session;
    if(_session) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionReceivedItem) name:FMSessionNextItemAvailableNotification object:_session];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stop) name:FMSessionActivePlacementChangedNotification object:_session];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stop) name:FMSessionActiveStationChangedNotification object:_session];

    }
}

- (void)setPlaybackState:(FMAudioPlayerPlaybackState)playbackState {
    _playbackState = playbackState;
    NSLog(@"Posting new playback state: %i", _playbackState);
    [[NSNotificationCenter defaultCenter] postNotificationName:FMAudioPlayerPlaybackStateDidChangeNotification object:self];
}

- (void)observeStatusChange:(AVPlayerStatus)status ofItem:(AVPlayerItem *)playerItem {
    switch (status) {
            /* Indicates that the status of the player is not yet known because
             it has not tried to load new media resources for playback */
        case AVPlayerStatusUnknown:
        {
            NSLog(@"Observed AVPlayerStatusUnknown");
        }
            break;

        case AVPlayerStatusReadyToPlay:
        {
            /* Once the AVPlayerItem becomes ready to play, i.e.
             [playerItem status] == AVPlayerItemStatusReadyToPlay,
             its duration can be fetched from the item. */
            NSLog(@"Observed AVPlayerStatusReadyToPlay");
            //todo: only set this state if we're not currently playing and it's the active item
            [self setPlaybackState:FMAudioPlayerPlaybackStateReadyToPlay];
            if(_playImmediately) {
                NSLog(@"Playing immediately");
                [self play];
            }
        }
            break;

        case AVPlayerStatusFailed:
        {
            NSLog(@"Observed AVPlayerStatusFailed");
            [self assetFailedToPrepareForPlayback:playerItem.error];
        }
            break;
    }
}

- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
	/* AVPlayerItem "status" property value observer. */
	if (context == FMAudioPlayerPlayerItemStatusObserverContext) {
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        [self observeStatusChange:status ofItem:object];
	}

    /* AVPlayer "rate" property value observer. */
	else if (context == FMAudioPlayerRateObservationContext) {
        BOOL playing = _player.rate > 0;
        if(playing) {
            [self setPlaybackState:FMAudioPlayerPlaybackStatePlaying];
        }
        else if(_isClientPaused) {
            [self setPlaybackState:FMAudioPlayerPlaybackStatePaused];
        }
        else {
            [self setPlaybackState:FMAudioPlayerPlaybackStateStalled];
        }
	}

	/* AVPlayer "currentItem" property observer.
     Called when the AVPlayer replaceCurrentItemWithPlayerItem:
     replacement will/did occur. */
	else if (context == FMAudioPlayerCurrentItemObservationContext) {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        NSLog(@"Observed current item change to: %@",newPlayerItem);
        /* New player item null? */
        if (newPlayerItem == (id)[NSNull null]) {
        }
        /* Replacement of player currentItem has occurred */
        else {
            [self.session playStarted]; //todo: is this definitely the right place for this?
        }
	}
	else {
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
    
    return;
}

#pragma mark - Playback

- (void)play {
    NSLog(@"Play Called");
    _isClientPaused = NO;
    _playImmediately = YES;

    if(![self isPreparedToPlay]) {
        [self prepareToPlay];
    }
    else if(!_isInternalPaused) {
        NSLog(@"Telling _player Play");
        [_player play];
        _playImmediately = NO;
    }
}

- (void)pause {
    _isClientPaused = YES;
    [_player pause];
    [self.session updatePlay:[self currentPlaybackTime]];
}

- (void)stop {
    NSLog(@"Stop Called");
    [_player pause];
    [_player removeAllItems];
}

- (void)skip {
    
}

@end

#undef kTracksKey
#undef kStatusKey
#undef kRateKey
#undef kPlayableKey
#undef kCurrentItemKey
