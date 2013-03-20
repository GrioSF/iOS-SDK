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


@interface FMSession () {
    FMAuth *_auth;
    NSMutableArray *_queuedRequests;
}
@property FMAuth *auth;
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

- (void)requestStationsForPlacement:(NSString *)placementId {
    FMAPIRequest *stationRequest = [FMAPIRequest requestStationsForPlacement:placementId];
    stationRequest.successBlock = ^(NSDictionary *result) {
        NSArray *stationJSON = result[@"stations"];
        if(![stationJSON isKindOfClass:[NSArray class]]) {
            [self stationRequestFailed:[NSError errorWithDomain:FMAPIErrorDomain code:FMErrorCodeUnexpectedReturnType userInfo:nil]];
        }
        else {
            [self stationRequestSucceeded:stationJSON];
        }
    };
    stationRequest.failureBlock = ^(NSError *error) {
        [self stationRequestFailed:error];
    };
    [self sendRequest:stationRequest];
}

- (void)requestStations {
    [self requestStationsForPlacement:self.activePlacementId];
}

- (void)stationRequestSucceeded:(NSArray *)stationJSON {
    NSMutableArray *stations = [[NSMutableArray alloc] initWithCapacity:[stationJSON count]];
    for(NSDictionary *stationDict in stationJSON) {
        if([stationDict isKindOfClass:[NSDictionary class]]) {
            FMStation *station = [[FMStation alloc] initWithJSON:stationDict];
            if(station) {
                [stations addObject:station];
            }
        }
    }
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
    FMAPIRequest *trackRequest = [FMAPIRequest requestPlayInPlacement:self.activePlacementId withStation:self.activeStation.identifier];
    trackRequest.successBlock = ^(id playJSON) {
        [self nextTrackSucceeded:playJSON];
    };
    trackRequest.failureBlock = ^(NSError *error) {
        [self nextTrackFailed:error];
    };
    [self sendRequest:trackRequest];
}

- (void)nextTrackSucceeded:(id)playJSON {
    //todo: process json into nextItem
    FMAudioItem *nextItem = nil;
    if(self.delegate && [self.delegate respondsToSelector:@selector(session:didReceiveItem:)]) {
        [self.delegate session:self didReceiveItem:nextItem];
    }
}

- (void)nextTrackFailed:(NSError *)error {
    if(self.delegate && [self.delegate respondsToSelector:@selector(session:didFailToReceiveItem:)]) {
        [self.delegate session:self didFailToReceiveItem:error];
    }

}

- (void)playStarted {

}

- (void)playPaused {

}

- (void)playCompleted {

}

- (void)requestSkip {

}

- (void)requestSkipIgnoringLimit {

}

@end
