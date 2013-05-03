//
//  FMAudioPlayer.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//  Contains code copyright (c) 2011 Apple Inc. from the sample code StitchedStreamPlayer
//

#import <AVFoundation/AVFoundation.h>
#import "FMAudioPlayer.h"
#import "FMAsset.h"

static void *FMAudioPlayerRateObservationContext = &FMAudioPlayerRateObservationContext;
static void *FMAudioPlayerCurrentItemObservationContext = &FMAudioPlayerCurrentItemObservationContext;
static void *FMAudioPlayerPlayerItemStatusObservationContext = &FMAudioPlayerPlayerItemStatusObservationContext;

NSString *const FMAudioPlayerPlaybackStateDidChangeNotification = @"FMAudioPlayerPlaybackStateDidChangeNotification";
NSString *const FMAudioPlayerSkipFailedNotification = @"FMAudioPlayerSkipFailedNotification";
NSString *const FMAudioPlayerSkipFailureErrorKey = @"FMAudioPlayerSkipFailureErrorKey";

#define kStatusKey @"status"
#define kRateKey @"rate"
#define kCurrentItemKey	@"currentItem"

@interface FMAudioPlayer () {
    AVQueuePlayer *_player;
    FMAsset *_loadingAsset;
    FMBandwidthMonitor *_bandwidthMonitor;
    BOOL _isClientPaused;
    BOOL _isTryingToPlay;
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
    [_bandwidthMonitor stop];
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

- (float)currentPlaybackRate {
    return _player.rate;
}

//todo: beef up with internal ability to play, or is this good enough?
- (BOOL)isPreparedToPlay {
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
    FMLogDebug(@"Prepare To Play");

    if(![self.session canRequestTracks]) {
        FMLogWarn(@"Can't prepare to play: session not ready");
        return;
    }

    if([_player.items count] > 1) {
        FMLogDebug(@"Already have items, ignoring");
        //already have a playing item, no need for additional preparation
        return;
    }

    [self setPlaybackState:FMAudioPlayerPlaybackStateWaitingForItem];
    if(!self.session.nextItem) {
        FMLogDebug(@"Requesting item");
        //FMSession will ignore requestNextTrack if a request is already in progress, but either way we'll get a notification when it's ready
        //todo: if there's an error, we won't get a callback. Is it ok to stay in WaitingForItem forever, or do we need a solution?
        [self.session requestNextTrack];
    }
    else {
        [self loadNextItem];
    }
}

- (void)loadNextItem {
    if(_loadingAsset) {
        //todo: assuming only one asset load at a time, get ready to queue up next tracks in advance!
        [_loadingAsset cancel];
    }
    if(self.session.nextItem) {
        _loadingAsset = [FMAsset assetWithAudioItem:self.session.nextItem];
        __block __weak FMAudioPlayer *blockSelf = self;
        [_loadingAsset setCompletionBlockWithSuccess:^(FMAsset *asset, AVPlayerItem *playerItem) {
            [blockSelf assetLoaded:asset];
        } failure:^(FMAsset *asset, NSError *error) {
            [blockSelf assetFailed:asset];
            FMLogWarn(@"Asset failed to load: %@", error);
        }];
        [_loadingAsset loadPlayerItem];
    }
}

- (void)sessionReceivedItem:(NSNotification *)notification {
    FMLogDebug(@"Session Received Item");
    if([_player.items count] < 1) {
        [self loadNextItem];
    }
}

- (void)assetLoaded:(FMAsset *)asset {
    FMLogDebug(@"Loaded Asset: %@", asset);
    //todo: make sure this is the asset we want
    [self registerForPlayerItemNotifications:asset.playerItem];
    [self applyMixVolumeToItem:asset.playerItem];
    
    [_player insertItem:asset.playerItem afterItem:nil];
    FMLogDebug(@"Added item to queue");
}

- (void)assetFailed:(FMAsset *)asset {
    FMLogWarn(@"Asset failed to load: %@", asset.loadError);
    _loadingAsset = nil;
    [self.session rejectItem:asset.audioItem];
}

- (void)assetFailedToPrepareForPlayback:(AVPlayerItem *)playerItem {
    FMLogWarn(@"Asset failed to prepare: %@", playerItem.error);
    if(playerItem == _loadingAsset.playerItem) {
        FMAudioItem *rejectedItem = _loadingAsset.audioItem;
        _loadingAsset = nil;
        [self.session rejectItem:rejectedItem];
    }
}

- (void)assetReadyForPlayback:(AVPlayerItem *)item {
    //todo: only set this state if we're not currently playing and it's the active item

    if(item == _loadingAsset.playerItem) {
        _loadingAsset = nil;

        _bandwidthMonitor = [[FMBandwidthMonitor alloc] init];
        _bandwidthMonitor.delegate = self;
        _bandwidthMonitor.monitoredItem = item;
    }

    FMLogDebug(@"Item ready with player rate %f", _player.rate);
    if(_player.rate == 0.0) {
        [self setPlaybackState:FMAudioPlayerPlaybackStateReadyToPlay];
    }
    else {
        [self setPlaybackState:FMAudioPlayerPlaybackStatePlaying];
    }
    if((_playImmediately || _isTryingToPlay) && !_isClientPaused) {
        FMLogDebug(@"Playing immediately");
        [self play];
    }
}

#pragma mark - Player Item Notifications

- (void)registerForPlayerItemNotifications:(AVPlayerItem *)item {
    /* Observe the player item "status" key to determine when it is ready to play. */
    [item addObserver:self
               forKeyPath:kStatusKey
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:FMAudioPlayerPlayerItemStatusObservationContext];

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
    if(&AVPlayerItemPlaybackStalledNotification) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:item];
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playerItemDidReachEnd:notification];
        });
        return;
    }
    FMLogDebug(@"Item reached end");
    [self unregisterForPlayerItemNotifications:notification.object];
    [_bandwidthMonitor stop];
    _bandwidthMonitor = nil;
    [self.session playCompleted];
    if([_player.items count] < 2) {
        FMLogDebug(@"Player Queue empty, preparing to play a new one");
        [self prepareToPlay];
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
    FMLogDebug(@"Item failed to reach end: %@", notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey]);
    //todo: recover!
}

// NOTE: This notification only gets called on iOS 6. Need to make sure any stall handling here is equivalent / doesn't conflict with the iOS 5 behavior.
- (void)playerItemStalled:(NSNotification *)notification {
    if(![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playerItemStalled:notification];
        });
        return;
    }
    FMLogDebug(@"Stalled");
    [self setPlaybackState:FMAudioPlayerPlaybackStateStalled];
}

- (void)updateLoadState {
    FMLogDebug(@"playerItem loadState updated");
    if(self.playbackState == FMAudioPlayerPlaybackStateStalled && _isTryingToPlay) {
        FMLogDebug(@"Want to recover from stall");
        if(_bandwidthMonitor.playbackLikelyToKeepUp) {
            FMLogDebug(@"Bandwidth monitor says go for it");
            [_player play];
        }
    }

    //todo: if bandwidth monitor says load is complete, start loading the next item
}

- (void)bandwidthMonitorDidUpdate:(FMBandwidthMonitor *)monitor {
    [self updateLoadState];
}

#pragma mark - State Handling

- (void)setSession:(FMSession *)session {
    if(_session) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:_session];
        [self stop];
    }
    _session = session;
    if(_session) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionReceivedItem:) name:FMSessionNextItemAvailableNotification object:_session];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(placementChanged:) name:FMSessionActivePlacementChangedNotification object:_session];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stationChanged:) name:FMSessionActiveStationChangedNotification object:_session];
    }
}

- (void)placementChanged:(NSNotification *)notification {
    FMLogDebug(@"Placement Changed");
    [self stop];
}

- (void)stationChanged:(NSNotification *)notification {
    FMLogDebug(@"Station Changed");
    [self stop];
    [self prepareToPlay];
}

- (void)setPlaybackState:(FMAudioPlayerPlaybackState)playbackState {
    if(_playbackState == playbackState) return;
    
    _playbackState = playbackState;
    FMLogDebug(@"Posting new playback state: %i", _playbackState);
    [[NSNotificationCenter defaultCenter] postNotificationName:FMAudioPlayerPlaybackStateDidChangeNotification object:self];
}

- (void)observeStatusChange:(AVPlayerStatus)status ofItem:(AVPlayerItem *)playerItem {
    switch (status) {
            /* Indicates that the status of the player is not yet known because
             it has not tried to load new media resources for playback */
        case AVPlayerStatusUnknown:
        {
            FMLogDebug(@"Observed AVPlayerStatusUnknown");
            //anything to do?
        }
            break;

        case AVPlayerStatusReadyToPlay:
        {
            /* Once the AVPlayerItem becomes ready to play, i.e.
             [playerItem status] == AVPlayerItemStatusReadyToPlay,
             its duration can be fetched from the item. */
            FMLogDebug(@"Observed AVPlayerStatusReadyToPlay");
            [self assetReadyForPlayback:playerItem];
        }
            break;

        case AVPlayerStatusFailed:
        {
            FMLogDebug(@"Observed AVPlayerStatusFailed");
            [self assetFailedToPrepareForPlayback:playerItem];
        }
            break;
    }
}

- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
	/* AVPlayerItem property value observers. */
	if(context == FMAudioPlayerPlayerItemStatusObservationContext) {
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        [self observeStatusChange:status ofItem:object];
	}
	else if (context == FMAudioPlayerRateObservationContext) {
        FMLogDebug(@"Got rate update: %f", _player.rate);
        BOOL playing = _player.rate > 0;
        if(playing) {
            [self setPlaybackState:FMAudioPlayerPlaybackStatePlaying];
        }
        else if(_isClientPaused) {
            [self setPlaybackState:FMAudioPlayerPlaybackStatePaused];
        }
        else if(_isTryingToPlay) {
            [self setPlaybackState:FMAudioPlayerPlaybackStateStalled];
        }
	}

	/* AVPlayer "currentItem" property observer.
     Called when the AVPlayer replaceCurrentItemWithPlayerItem:
     replacement will/did occur. */
	else if (context == FMAudioPlayerCurrentItemObservationContext) {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        FMLogDebug(@"Observed current item change to: %@",newPlayerItem);

        if(newPlayerItem != (id)[NSNull null]) {
            [self.session playStarted];
        }
	}
	else {
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
    
    return;
}

#pragma mark - Playback

- (void)play {
    FMLogDebug(@"Play Called");
    _isClientPaused = NO;
    _playImmediately = YES;

    if(![self isPreparedToPlay]) {
        [self prepareToPlay];
    }
    else {
        FMLogDebug(@"Telling _player Play");
        [_player play];
        [_bandwidthMonitor start];
        _isTryingToPlay = YES;
        _playImmediately = NO;
        if(_player.rate > 0.0) {
            [self setPlaybackState:FMAudioPlayerPlaybackStatePlaying];
        }
    }
}

- (void)pause {
    _isClientPaused = YES;
    _isTryingToPlay = NO;
    [_player pause];
    [_bandwidthMonitor stop];
    [self.session updatePlay:[self currentPlaybackTime]];
}

- (void)stop {
    FMLogDebug(@"Stop Called");
    _isTryingToPlay = NO;
    _isClientPaused = NO;
    [_loadingAsset cancel];
    _loadingAsset = nil;
    [_player pause];
    [_player removeAllItems];
    [self setPlaybackState:FMAudioPlayerPlaybackStateComplete];
    [_bandwidthMonitor stop];
}

- (void)skip {
    FMLogDebug(@"Skip Called");
    FMAudioPlayerPlaybackState originalState = self.playbackState;
    AVPlayerItem *itemToRemove = _player.currentItem;
    [self setPlaybackState:FMAudioPlayerPlaybackStateRequestingSkip];
    [self.session requestSkipWithSuccess:^{
        [_player removeItem:itemToRemove];
        [self play];
    } failure:^(NSError *error) {
        [self setPlaybackState:originalState];
        [[NSNotificationCenter defaultCenter] postNotificationName:FMAudioPlayerSkipFailedNotification object:self userInfo:@{FMAudioPlayerSkipFailureErrorKey : error}];
    }];
}

@end

#undef kStatusKey
#undef kRateKey
#undef kCurrentItemKey
