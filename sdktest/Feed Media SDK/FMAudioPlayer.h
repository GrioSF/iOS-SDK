//
//  FMAudioPlayer.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMStation.h"
#import "FMAudioItem.h"
#import "FMError.h"
#import "FMLog.h"

extern NSString *const FMAudioPlayerPlaybackStateDidChangeNotification;
extern NSString *const FMAudioPlayerCurrentItemDidChangeNotification;
extern NSString *const FMAudioPlayerActiveStationDidChangeNotification;
extern NSString *const FMAudioPlayerActivePlacementDidChangeNotification;
extern NSString *const FMAudioPlayerSkipFailedNotification;
extern NSString *const FMAudioPlayerSkipFailureErrorKey;    //userInfo error key for FMAudioPlayerSkipFailedNotification

extern NSString *const FMAudioFormatMP3;
extern NSString *const FMAudioFormatAAC;

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

///-----------------------------------------------------
/// @name Initial Setup
///-----------------------------------------------------

+ (void)setClientToken:(NSString *)token secret:(NSString *)secret;
+ (FMAudioPlayer *)sharedPlayer;

@property (nonatomic, copy, setter=setPlacement:) NSString *activePlacementId;

///-----------------------------------------------------
/// @name Audio Playback
///-----------------------------------------------------

- (void)prepareToPlay;
- (void)play;
- (void)pause;
- (void)stop;
- (void)skip;

@property (nonatomic) float mixVolume; // value between 0.0 and 1.0 relative to system volume
@property (nonatomic, readonly) FMAudioPlayerPlaybackState playbackState;
@property (nonatomic, readonly) NSTimeInterval currentPlaybackTime;
@property (nonatomic, readonly) NSTimeInterval currentItemDuration;
@property (nonatomic, readonly) float currentPlaybackRate; //seeking is not supported, so this will always be 0.0 or 1.0
@property (nonatomic, readonly) BOOL isPreparedToPlay;
@property (nonatomic, readonly) FMAudioItem *currentItem;

///-----------------------------------------------------
/// @name Configuring The Session
///-----------------------------------------------------

/**
 On success, will trigger the success callback with an NSArray of FMStations, which can then
 be used in the `-setStation:` call.
 If no station is set, the player will use the placement's default station as configured
 using the web interface.
 */
- (void)requestStationsForPlacement:(NSString *)placementId
                        withSuccess:(void (^)(NSArray *stations))success
                            failure:(void (^)(NSError *error))failure;

@property (nonatomic, copy, setter=setStation:) FMStation *activeStation;

/**
 Order specifies priority (earlier elements are preferred).
 Nil-ing this property will allow any format to be served, but is not recommended.
 Set to @[FMAudioFormatMP3] to exclude AAC files.
 Defaults to @[FMAudioFormatAAC,FMAudioFormatMP3].
 */
@property (nonatomic, strong) NSArray *supportedAudioFormats;

/**
 Set to specify available bandwidth, in kbps. Set to 0 to request the highest available quality.
 Defaults to 48.
 */
@property (nonatomic) NSInteger maxBitrate;



@end
