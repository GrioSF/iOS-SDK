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


@protocol FMSessionDelegate <NSObject>

@optional
- (void)session:(FMSession *)session didReceiveStations:(NSArray *)stations;
- (void)session:(FMSession *)session didFailToReceiveStations:(NSError *)error;

- (void)session:(FMSession *)session didReceiveItem:(FMAudioItem *)nextItem;
- (void)session:(FMSession *)session didFailToReceiveItem:(NSError *)error;
- (void)session:(FMSession *)session didFailToSkipTrack:(NSError *)error;

@end


@interface FMSession : NSObject

@property (nonatomic, assign) id<FMSessionDelegate> delegate;
@property (nonatomic) NSString *currentStationId;
@property (nonatomic) NSString *placementId;
@property (nonatomic) FMAudioFormat *preferredCodec;    //defaults to FMAudioFormatAny
@property (nonatomic, readonly) FMAudioItem *currentItem;
@property (nonatomic) BOOL debugLogEnabled;             //prints debug information to NSLog

+ (void)setClientToken:(NSString *)token secret:(NSString *)secret;

+ (FMSession *)sessionWithPlacementId:(NSString *)placementId;
- (id)initWithPlacementId:(NSString *)placementId;

- (void)requestStations;
- (void)setStation:(FMStation *)station;
- (void)setStationWithId:(NSString *)stationId;

// These are only required if not using the FMAudioPlayer
- (void)requestNextTrack;
- (void)playStarted;
- (void)playPaused;
- (void)playCompleted;
- (void)requestSkip;
- (void)requestSkipIgnoringLimit;   // Use only to resolve system issues, e.g. unplayable track

@end