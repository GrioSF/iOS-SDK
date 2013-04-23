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

#define kFMAuthStoragePath @"FeedMedia/"
#define kFMAuthStorageName @"FMAuth.plist"

#define kFMSessionDefaultBitrate 128

NSString *const FMSessionCurrentItemChangedNotification = @"FMSessionCurrentItemChangedNotification";
NSString *const FMSessionNextItemAvailableNotification = @"FMSessionNextItemAvailableNotification";
NSString *const FMSessionActivePlacementChangedNotification = @"FMSessionActivePlacementChangedNotification";
NSString *const FMSessionActiveStationChangedNotification = @"FMSessionActiveStationChangedNotification";
NSString *const FMAudioFormatMP3 = @"mp3";
NSString *const FMAudioFormatAAC = @"aac";

@interface FMSession () {
    FMAuth *_auth;
    NSMutableArray *_queuedRequests;
    NSMutableArray *_requestsInProgress;
    BOOL _nextTrackInProgress;
}
@property FMAuth *auth;
@property (nonatomic) FMAudioItem *currentItem;
@property (nonatomic) FMAudioItem *nextItem;
@end

@implementation FMSession

+ (void)setClientToken:(NSString *)token secret:(NSString *)secret {

    if(token == nil || [token isEqualToString:@""] || secret == nil || [secret isEqualToString:@""]) {
        FMLogError(@"ERROR: FMSession must be initialized with a token and secret");
        return;
    }
    [[FMSession sharedSession] cancelOutstandingRequests];
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
        _requestsInProgress = [[NSMutableArray alloc] init];
        _supportedAudioFormats = @[FMAudioFormatAAC,FMAudioFormatMP3];
        _maxBitrate = kFMSessionDefaultBitrate;
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
        FMLogDebug(@"Next Item Set, sending Notification");
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
}

- (void)setStation:(FMStation *)activeStation {
    if(activeStation == nil && _activeStation == nil) return;
    if([activeStation isEqual:_activeStation]) return;

    _activeStation = [activeStation copy];
    [self cancelOutstandingRequests];
    self.currentItem = nil;
    self.nextItem = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:FMSessionActiveStationChangedNotification object:self userInfo:nil];
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
                FMLogError(@"ERROR: Failed to save Feed Media cuuid");
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
        FMLogError(@"ERROR: FeedMedia Failed to synchronize clock to server: %@",error);
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
        FMLogError(@"ERROR: FeedMedia failed to obtain cuuid: %@",error);
    };
    FMLogDebug(@"Sending cuuid Request");
    FMLogDebug(@"Cuuid request has auth: %@",cuuidRequest.auth);
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

#pragma mark - REQUEST HANDLING

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
    
    __block __weak FMAPIRequest *blockSafeRequest = request;
    void (^success)(NSDictionary *) = request.successBlock;
    void (^failure)(NSError *) = request.failureBlock;
    request.successBlock = ^(NSDictionary *result) {
        if(success) {
            success(result);
        }
        [_requestsInProgress removeObject:blockSafeRequest];
    };
    request.failureBlock = ^(NSError *error) {
        if(failure) {
            failure(error);
        }
        [_requestsInProgress removeObject:blockSafeRequest];
    };
    
    [_requestsInProgress addObject:request];
    [request send];
}

- (void)sendQueuedRequests {
    //Empty _queuedRequests first so that sendRequest: can requeue them if there's a problem
    NSArray *requestsToSend = [NSArray arrayWithArray:_queuedRequests];
    [_queuedRequests removeAllObjects];

    for(FMAPIRequest *request in requestsToSend) {
        [self sendRequest:request];
    }
}

- (void)cancelOutstandingRequests {
    [_queuedRequests removeAllObjects];
    for(FMAPIRequest *request in _requestsInProgress) {
        [request cancel];
    }
    [_requestsInProgress removeAllObjects];
}

#pragma mark - STATIONS

- (void)requestStationsForPlacement:(NSString *)placementId
                        withSuccess:(void (^)(NSArray *stations))success
                            failure:(void (^)(NSError *error))failure {

    placementId = placementId ?: self.activePlacementId;
    NSAssert(placementId != nil, @"Must either set FMSession's placementId in advance or pass explicit placementId to -requestStations call");

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
    [self requestStationsForPlacement:nil];
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

    NSString *supportedFormatString = [self.supportedAudioFormats componentsJoinedByString:@","];
    FMAPIRequest *trackRequest = trackRequest = [FMAPIRequest requestPlayInPlacement:self.activePlacementId
                                            withStation:self.activeStation.identifier
                                                formats:supportedFormatString
                                             maxBitrate:[NSNumber numberWithInteger:self.maxBitrate]];
    
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
    FMLogDebug(@"Next Track Succeeded: %@",nextItem);
    _nextTrackInProgress = NO;
    self.nextItem = nextItem;
}

- (void)nextTrackFailed:(NSError *)error {
    FMLogDebug(@"Next Track Failed: %@",error);
    _nextTrackInProgress = NO;

    if(self.delegate && [self.delegate respondsToSelector:@selector(session:didFailToReceiveItem:)]) {
        [self.delegate session:self didFailToReceiveItem:error];
    }
}

- (void)playStarted {
    self.currentItem = self.nextItem;
    self.nextItem = nil;

    FMAPIRequest *playRequest = [FMAPIRequest requestStart:self.currentItem.playId];
    playRequest.failureBlock = ^(NSError *error) {
        FMLogError(@"ERROR: Failed to start play on %@. Next item will not be available! %@", self.currentItem, error);
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
        FMLogError(@"ERROR: Failed to register play completion: %@. Next item will not be available!", error);
    };
    [self sendRequest:completeRequest];
}

- (void)requestSkip:(BOOL)forced
        withSuccess:(void (^)(void))success
            failure:(void (^)(NSError *error))failure {
    
    FMAPIRequest *skipRequest = [FMAPIRequest requestSkip:self.currentItem.playId force:forced elapsed:-1];
    skipRequest.successBlock = ^(NSDictionary *result) {
        FMLogDebug(@"Skip success");
        self.currentItem = nil;
        [self requestNextTrack];
        if(success) {
            success();
        }
    };
    skipRequest.failureBlock = ^(NSError *error) {
        FMLogWarn(@"Failed to skip: %@", error);
        if(failure) {
            failure(error);
        }
    };
    [self sendRequest:skipRequest];
}

- (void)requestSkip {
    [self requestSkip:NO withSuccess:nil failure:nil];
}

- (void)requestSkipWithSuccess:(void (^)(void))success
                       failure:(void (^)(NSError *error))failure {
    [self requestSkip:NO withSuccess:success failure:failure];
}

- (void)requestSkipIgnoringLimit {
    [self requestSkip:YES withSuccess:nil failure:nil];
}

- (void)requestSkipIgnoringLimitWithSuccess:(void (^)(void))success
                                    failure:(void (^)(NSError *error))failure {
    [self requestSkip:YES withSuccess:success failure:failure];
}

@end

#undef kFMAuthStoragePath
#undef kFMAuthStorageName
#undef kFMSessionDefaultBitrate
