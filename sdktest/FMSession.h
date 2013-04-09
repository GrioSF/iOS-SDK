//
//  FMSession.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FMAudioItem, FMSession, FMStation;

typedef enum FMAudioFormat : NSUInteger {
    FMAudioFormatAny,
    FMAudioFormatMP3,
    FMAudioFormatAAC
} FMAudioFormat;

extern NSString *const FMSessionCurrentItemChangedNotification;
extern NSString *const FMSessionNextItemAvailableNotification;
extern NSString *const FMSessionActivePlacementChangedNotification;
extern NSString *const FMSessionActiveStationChangedNotification;

@protocol FMSessionDelegate <NSObject>

@optional
- (void)session:(FMSession *)session didReceiveStations:(NSArray *)stations;
- (void)session:(FMSession *)session didFailToReceiveStations:(NSError *)error;
- (void)session:(FMSession *)session didFailToReceiveItem:(NSError *)error;
- (void)session:(FMSession *)session didFailToSkipTrack:(NSError *)error;

@end


@interface FMSession : NSObject

@property (nonatomic, assign) id<FMSessionDelegate> delegate;
@property (nonatomic, copy, setter=setStation:) FMStation *activeStation;
@property (nonatomic, copy, setter=setPlacement:) NSString *activePlacementId;
@property (nonatomic) FMAudioFormat *preferredCodec;    //defaults to FMAudioFormatAny
@property (nonatomic, readonly) FMAudioItem *currentItem;
@property (nonatomic, readonly) FMAudioItem *nextItem;
@property (nonatomic, readonly) BOOL skipAvailable;
@property (nonatomic) BOOL debugLogEnabled;             //prints debug information to NSLog

+ (void)setClientToken:(NSString *)token secret:(NSString *)secret;
+ (FMSession *)sharedSession;

- (void)requestStations;
- (void)requestStationsForPlacement:(NSString *)placementId;
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
 Requests the next track for the current placement/station, which will populate the `nextItem` property and trigger the `FMSessionNextItemAvailableNotification` notification on success. Only has effect if `nextItem` is nil.
 */
 - (void)requestNextTrack;

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
    May fail if the user is out of skips, in which case the delegate will be notified.
 */
- (void)requestSkip;

/**
 Behaves like `-requestSkip`, but ignores the user's skip limit. Use only to resolve system issues, e.g. unplayable track
 */
- (void)requestSkipIgnoringLimit;

@end