//
//  FMAudioPlayer.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMSession.h"

extern NSString *const FMAudioPlayerPlaybackStateDidChangeNotification;
extern NSString *const FMAudioPlayerSkipFailedNotification;
extern NSString *const FMAudioPlayerSkipFailureErrorKey;    //userInfo error key for FMAudioPlayerSkipFailedNotification

typedef enum FMAudioPlayerPlaybackState : NSUInteger {
    FMAudioPlayerPlaybackStateWaitingForItem,
    FMAudioPlayerPlaybackStateReadyToPlay,
    FMAudioPlayerPlaybackStatePlaying,
    FMAudioPlayerPlaybackStatePaused,
    FMAudioPlayerPlaybackStateStalled,
    FMAudioPlayerPlaybackStateRequestingSkip,
    FMAudioPlayerPlaybackStateComplete
} FMAudioPlayerPlaybackState;

@interface FMAudioPlayer : NSObject 

@property (nonatomic) FMSession *session; //note: playback will stop automatically if the placement or station are changed
@property (nonatomic) float mixVolume; // value between 0.0 and 1.0 relative to system volume
@property (nonatomic, readonly) FMAudioPlayerPlaybackState playbackState;
@property (nonatomic, readonly) NSTimeInterval currentPlaybackTime;
@property (nonatomic, readonly) NSTimeInterval currentItemDuration;
@property (nonatomic, readonly) float currentPlaybackRate; //seeking is not supported, so this will always be 0.0 or 1.0
@property (nonatomic, readonly) BOOL isPreparedToPlay;

+ (FMAudioPlayer *)playerWithSession:(FMSession *)session;
- (id)initWithSession:(FMSession *)session;

- (void)prepareToPlay;
- (void)play;
- (void)pause;
- (void)stop;
- (void)skip;

@end
