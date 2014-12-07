//
//  FMSession.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMSession, FMAudioItem, FMStation;

extern NSString *const FMSessionCurrentItemDidChangeNotification;
extern NSString *const FMSessionNextItemAvailableNotification;
extern NSString *const FMSessionActivePlacementDidChangeNotification;
extern NSString *const FMSessionActiveStationDidChangeNotification;

extern NSString *const FMAudioFormatMP3;
extern NSString *const FMAudioFormatAAC;

@interface FMSession : NSObject

@property (nonatomic, copy, setter=setStation:) FMStation *activeStation;
@property (nonatomic, copy, setter=setPlacement:) NSString *activePlacementId;

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

@property (nonatomic, readonly) FMAudioItem *currentItem;
@property (nonatomic, readonly) FMAudioItem *nextItem;

+ (void)setClientToken:(NSString *)token secret:(NSString *)secret;
+ (FMSession *)sharedSession;

- (void)requestStationsForPlacement:(NSString *)placementId
                        withSuccess:(void (^)(NSArray *stations))success
                            failure:(void (^)(NSError *error))failure;

///-----------------------------------------------------
/// @name Playback State Controls
///-----------------------------------------------------

/**
 These are only required if not using the FMAudioPlayer.
 */

/**
 Returns whether or not the session is ready for requests, e.g. a valid client token, secret, and placementId has been set.
 */
- (BOOL)canRequestItems;

/**
 Requests the next item for the current placement/station, which will populate the `nextItem` property and trigger the `FMSessionNextItemAvailableNotification` notification on success. Only has effect if `nextItem` is nil.
 */
 - (void)requestNextItem;

/** 
 Moves the nextItem into the currentItem position and notifies the server that the play began. If a previous item is playing, `-playCompleted` or `-requestSkip` must be called first.
 */
- (void)playStarted;

/**
 Notifies the server of how much of the current item has been played for reporting purposes. Can be called periodically or specifically on events such as when playback is paused.
 
 @param elapsedTime The amount of time the currentItem has already been played
 */
- (void)updatePlay:(NSTimeInterval)elapsedTime;

/**
 Notifies the server that playthrough completed successfully. It nils out the currentItem in preparation for the next play to be started.
 */
- (void)playCompleted;

/**
 If successful, `-requestSkip` will behave like `-playCompleted` by nilling out the currentItem in preparation for the next `-playStarted` call.
    May fail if the user is out of skips, in which case the delegate will be notified and the failure block (if any) will be called.
 
 @param success Optional block to be called if the server grants the skip
 @param failure Optional block to be called if the server rejects the skip
 */
- (void)requestSkip;
- (void)requestSkipWithSuccess:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure;

/**
 Use only to resolve system issues, e.g. unplayable content.
 Automatically requests a new item.
 
 @param item The item that failed. Should be either the FMSession's currentItem or nextItem, otherwise the call will be ignored.
  */
- (void)rejectItem:(FMAudioItem *)item;

/**
 Register a like/unlike request or a dislike request for the current content.
  */
- (void)requestLike;
- (void)requestUnlike;
- (void)requestDislike;

@end