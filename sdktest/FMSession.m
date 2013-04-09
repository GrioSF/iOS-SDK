//
//  FMSession.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMSession.h"
#import "FMAuth.h"
#import "FMAPIRequest.h"
#import "FMStation.h"
#import "FMAudioItem.h"
#import "FMError.h"

#define kFMAuthStoragePath @"FeedMedia/"
#define kFMAuthStorageName @"FMAuth.plist"

NSString *const FMSessionCurrentItemChangedNotification = @"FMSessionCurrentItemChangedNotification";
NSString *const FMSessionNextItemAvailableNotification = @"FMSessionNextItemAvailableNotification";
NSString *const FMSessionActivePlacementChangedNotification = @"FMSessionActivePlacementChangedNotification";
NSString *const FMSessionActiveStationChangedNotification = @"FMSessionActiveStationChangedNotification";

@interface FMSession () {
    FMAuth *_auth;
    NSMutableArray *_queuedRequests;
    BOOL _nextTrackInProgress;
}
@property FMAuth *auth;
@property (nonatomic) FMAudioItem *currentItem;
@property (nonatomic) FMAudioItem *nextItem;
@property (nonatomic) BOOL skipAvailable;
@end

@implementation FMSession

+ (void)setClientToken:(NSString *)token secret:(NSString *)secret {

    if(token == nil || [token isEqualToString:@""] || secret == nil || [secret isEqualToString:@""]) {
        NSLog(@"ERROR: FMSession must be initialized with a token and secret");
        return;
    }
    [FMSession sharedSession].auth.clientToken = token;
    [FMSession sharedSession].auth.clientSecret = secret;

    if([FMSession sharedSession].auth.cuuid == nil || [[FMSession sharedSession].auth.cuuid isEqualToString:@""]) {
        [[FMSession sharedSession] requestCuuid];
    }
    [[FMSession sharedSession] updateServerTime];
}

+ (FMSession *)sharedSession {
    static FMSession *_sharedSession;
    static dispatch_once_t singletonToken;
    dispatch_once(&singletonToken, ^{
        _sharedSession = [[FMSession alloc] init];
    });
    return _sharedSession;
}

- (id)init {
    if(self = [super init]) {
        _queuedRequests = [[NSMutableArray alloc] init];
        _auth = [self authFromDisk];
        if(_auth == nil) {
            _auth = [[FMAuth alloc] init];
        }
    }
    return self;
}

- (void)setNextItem:(FMAudioItem *)nextItem {
    if([nextItem isEqual:_nextItem]) return;

    _nextItem = nextItem;
    if(nextItem != nil) {
        NSLog(@"Next Item Set, sending Notification");
        [[NSNotificationCenter defaultCenter] postNotificationName:FMSessionNextItemAvailableNotification object:self userInfo:nil];
    }
}

- (void)setCurrentItem:(FMAudioItem *)currentItem {
    if(currentItem == nil && _currentItem == nil) return;
    if([currentItem isEqual:_currentItem]) return;

    _currentItem = currentItem;
    [[NSNotificationCenter defaultCenter] postNotificationName:FMSessionCurrentItemChangedNotification object:self userInfo:nil];
}

- (void)setPlacement:(NSString *)activePlacementId {
    if(activePlacementId == nil && _activePlacementId == nil) return;
    if([activePlacementId isEqualToString:_activePlacementId]) return;

    _activePlacementId = [activePlacementId copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:FMSessionActivePlacementChangedNotification object:self userInfo:nil];
    self.activeStation = nil;
    //todo: any other sideeffects? Clear out current/next items?
}

- (void)setStation:(FMStation *)activeStation {
    if(activeStation == nil && _activeStation == nil) return;
    if([activeStation isEqual:_activeStation]) return;

    _activeStation = [activeStation copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:FMSessionActiveStationChangedNotification object:self userInfo:nil];
    //todo: any other sideeffects? Clear out current/next items?
}

#pragma mark - AUTH

+ (NSString *)saveDirectory {
    NSArray *libraryPathArray = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *libraryPath = [libraryPathArray lastObject];
    NSString *saveDirectory = [libraryPath stringByAppendingPathComponent:kFMAuthStoragePath];
    if(saveDirectory) {
        BOOL isDirectory = NO;
        BOOL pathExists = [[NSFileManager defaultManager] fileExistsAtPath:saveDirectory isDirectory:&isDirectory];
        if(!pathExists || !isDirectory) {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:saveDirectory withIntermediateDirectories:YES attributes:nil error:&error];
            if(error) {
                NSLog(@"ERROR: Failed to save Feed Media cuuid");
            }
        }
    }
    return saveDirectory;
}

- (void)updateServerTime {
    FMAPIRequest *timeRequest = [FMAPIRequest requestServerTime];
    timeRequest.successBlock = ^(NSDictionary *result) {
        id timeObject = result[@"time"];
        if([timeObject respondsToSelector:@selector(doubleValue)]) {
            [self.auth setCurrentServerTime:[timeObject doubleValue]];
            [self storeAuthToDisk];
        }
    };
    timeRequest.failureBlock = ^(NSError *error) {
        NSLog(@"ERROR: FeedMedia Failed to synchronize clock to server: %@",error);
    };
    [timeRequest send];
}

- (void)requestCuuid {
    FMAPIRequest *cuuidRequest = [FMAPIRequest requestCUUID];
    cuuidRequest.auth = self.auth;
    cuuidRequest.successBlock = ^(NSDictionary *result) {
        id cuuid = result[@"client_id"];
        if([cuuid isKindOfClass:[NSNumber class]] && ![cuuid isEqual:@(0)]) {
            cuuid = [NSString stringWithFormat:@"%ld",(long)[(NSNumber *)cuuid integerValue]];
        }
        if([cuuid isKindOfClass:[NSString class]] && ![cuuid isEqualToString:@""]) {
            self.auth.cuuid = cuuid;
            [self storeAuthToDisk];
            [self sendQueuedRequests];
        }
    };
    cuuidRequest.failureBlock = ^(NSError *error) {
        NSLog(@"ERROR: FeedMedia failed to obtain cuuid: %@",error);
    };
    NSLog(@"Sending cuuid Request");
    NSLog(@"Cuuid request has auth: %@",cuuidRequest.auth);
    [cuuidRequest send];
}

- (BOOL)storeAuthToDisk {
    NSString *filepath = [[FMSession saveDirectory] stringByAppendingPathComponent:kFMAuthStorageName];
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [self.auth encodeWithCoder:archiver];
    [archiver finishEncoding];
    return [data writeToFile:filepath atomically:YES];
}

- (FMAuth *)authFromDisk {
    NSString *filepath = [[FMSession saveDirectory] stringByAppendingPathComponent:kFMAuthStorageName];
    NSData *authData = [[NSData alloc] initWithContentsOfFile:filepath];
    if(!authData) return nil;

    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:authData];
    FMAuth *auth = [[FMAuth alloc] initWithCoder:unarchiver];
    return auth;
}

#pragma mark - REQUEST QUEUEING

- (void)sendRequest:(FMAPIRequest *)request {
    if(request.authRequired) {
        if(self.auth.cuuid == nil || [self.auth.cuuid isEqualToString:@""]) {
            [_queuedRequests addObject:request];
            return;
        }
        else {
            request.auth = self.auth;
        }
    }
    [request send];
}

- (void)sendQueuedRequests {
    for(FMAPIRequest *request in _queuedRequests) {
        request.auth = self.auth;
        [request send];
    }
    [_queuedRequests removeAllObjects];
}

#pragma mark - STATIONS

- (void)requestStationsForPlacement:(NSString *)placementId
                        withSuccess:(void (^)(NSArray *stations))success
                            failure:(void (^)(NSError *error))failure {
    FMAPIRequest *stationRequest = [FMAPIRequest requestStationsForPlacement:placementId];
    stationRequest.successBlock = ^(NSDictionary *result) {
        NSArray *stationJSON = result[@"stations"];
        if(![stationJSON isKindOfClass:[NSArray class]]) {
            NSError *error = [NSError errorWithDomain:FMAPIErrorDomain code:FMErrorCodeUnexpectedReturnType userInfo:nil];
            if(failure) {
                failure(error);
            }
            [self stationRequestFailed:error];
        }
        else {
            NSArray *stations = [self stationsFromJSON:stationJSON];
            if(success) {
                success(stations);
            }
            [self stationRequestSucceeded:stations];
        }
    };
    stationRequest.failureBlock = ^(NSError *error) {
        if(failure) {
            failure(error);
        }
        [self stationRequestFailed:error];
    };
    [self sendRequest:stationRequest];
}


- (void)requestStationsForPlacement:(NSString *)placementId {
    [self requestStationsForPlacement:placementId withSuccess:nil failure:nil];
}

- (void)requestStations {
    [self requestStationsForPlacement:self.activePlacementId];
}

- (NSArray *)stationsFromJSON:(NSArray *)stationJSON {
    NSMutableArray *stations = [[NSMutableArray alloc] initWithCapacity:[stationJSON count]];
    for(NSDictionary *stationDict in stationJSON) {
        if([stationDict isKindOfClass:[NSDictionary class]]) {
            FMStation *station = [[FMStation alloc] initWithJSON:stationDict];
            if(station) {
                [stations addObject:station];
            }
        }
    }
    return stations;
}

- (void)stationRequestSucceeded:(NSArray *)stations {
    if(self.delegate && [self.delegate respondsToSelector:@selector(session:didReceiveStations:)]) {
        [self.delegate session:self didReceiveStations:stations];
    }
}

- (void)stationRequestFailed:(NSError *)error {
    if(self.delegate && [self.delegate respondsToSelector:@selector(session:didFailToReceiveStations:)]) {
        [self.delegate session:self didFailToReceiveStations:error];
    }
}

#pragma mark - PLAYBACK

- (void)requestNextTrack {
    if(self.nextItem != nil || _nextTrackInProgress) return;

    _nextTrackInProgress = YES;

    FMAPIRequest *trackRequest = [FMAPIRequest requestPlayInPlacement:self.activePlacementId withStation:self.activeStation.identifier];
    trackRequest.successBlock = ^(NSDictionary *result) {
        NSDictionary *playJSON = result[@"play"];
        FMAudioItem *nextItem = nil;

        if([playJSON isKindOfClass:[NSDictionary class]]) {
            nextItem = [[FMAudioItem alloc] initWithJSON:playJSON];
        }
        
        if(nextItem == nil) {
            [self nextTrackFailed:[NSError errorWithDomain:FMAPIErrorDomain code:FMErrorCodeUnexpectedReturnType userInfo:nil]];
        }
        else {
            [self nextTrackSucceeded:nextItem];
        }
    };
    trackRequest.failureBlock = ^(NSError *error) {
        [self nextTrackFailed:error];
    };
    [self sendRequest:trackRequest];
}

- (void)nextTrackSucceeded:(FMAudioItem *)nextItem {
    NSLog(@"Next Track Succeeded: %@",nextItem);
    _nextTrackInProgress = NO;
    self.nextItem = nextItem;
}

- (void)nextTrackFailed:(NSError *)error {
    NSLog(@"Next Track Failed: %@",error);
    _nextTrackInProgress = NO;

    if(self.delegate && [self.delegate respondsToSelector:@selector(session:didFailToReceiveItem:)]) {
        [self.delegate session:self didFailToReceiveItem:error];
    }
}

- (void)playStarted {
    self.currentItem = self.nextItem;
    self.nextItem = nil;

    FMAPIRequest *playRequest = [FMAPIRequest requestStart:self.currentItem.playId];
    playRequest.successBlock = ^(NSDictionary *result) {
        self.skipAvailable = [result[@"can_skip"] boolValue];
        //todo: request nextTrack automatically?
    };
    playRequest.failureBlock = ^(NSError *error) {
        NSLog(@"ERROR: Failed to start play on %@. Next item will not be available! %@", self.currentItem, error);
    };
    [self sendRequest:playRequest];
}

- (void)updatePlay:(NSTimeInterval)elapsedTime {
    FMAPIRequest *elapseRequest = [FMAPIRequest requestElapse:self.currentItem.playId time:elapsedTime];
    [self sendRequest:elapseRequest];
}

- (void)playCompleted {
    NSString *playId = self.currentItem.playId;
    self.currentItem = nil;

    FMAPIRequest *completeRequest = [FMAPIRequest requestComplete:playId];
    completeRequest.failureBlock = ^(NSError *error) {
        NSLog(@"ERROR: Failed to register play completion: %@. Next item will not be available!", error);
    };
    [self sendRequest:completeRequest];
}

//todo: What is full behavior on success? do we automatically initiate a nextTrack?
- (void)requestSkip:(BOOL)forced {
    FMAPIRequest *skipRequest = [FMAPIRequest requestSkip:self.currentItem.playId force:forced elapsed:-1];
    skipRequest.successBlock = ^(NSDictionary *result) {
        self.currentItem = nil;
    };
    skipRequest.failureBlock = ^(NSError *error) {
        if([[error domain] isEqualToString:FMAPIErrorDomain] && [error code] == FMErrorCodeInvalidSkip) {
            self.skipAvailable = NO;
        }
        else {
            NSLog(@"ERROR: Failed to skip: %@", error);
        }
    };
}

- (void)requestSkip {
    [self requestSkip:NO];
}

- (void)requestSkipIgnoringLimit {
    [self requestSkip:YES];
}

@end
