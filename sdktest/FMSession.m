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
}
@property FMAuth *auth;
@end

@implementation FMSession

static NSLock *fmsession_credentialLock;
static NSString *fmsession_clientToken = nil;
static NSString *fmsession_clientSecret = nil;

+ (void)setClientToken:(NSString *)token secret:(NSString *)secret {
    static dispatch_once_t lockToken;
    dispatch_once(&lockToken, ^{
        fmsession_credentialLock = [[NSLock alloc] init];
    });

    if(token == nil || [token isEqualToString:@""] || secret == nil || [secret isEqualToString:@""]) {
        NSLog(@"ERROR: FMSession must be initialized with a token and secret");
        return;
    }
    [fmsession_credentialLock lock];
    fmsession_clientToken = [token copy];
    fmsession_clientSecret = [secret copy];
    [fmsession_credentialLock unlock];
}

+ (NSString *)clientToken {
    NSString *ret = nil;
    [fmsession_credentialLock lock];
    ret = [fmsession_clientToken copy];
    [fmsession_credentialLock unlock];
    return ret;
}

+ (NSString *)clientSecret {
    NSString *ret = nil;
    [fmsession_credentialLock lock];
    ret = [fmsession_clientSecret copy];
    [fmsession_credentialLock unlock];
    return ret;
}

+ (FMSession *)sessionWithPlacementId:(NSString *)placementId {
    return [[FMSession alloc] initWithPlacementId:placementId];
}

- (id)initWithPlacementId:(NSString *)placementId {
    if(self = [super init]) {
        self.placementId = placementId;
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
}

- (void)setAuth:(FMAuth *)auth {
    @synchronized(self) {
        _auth = auth;
    }
}

- (FMAuth *)auth {
    if(_auth == nil) {
        self.auth = [self authFromDisk];
    }
    if(self.auth == nil) {
        self.auth = [[FMAuth alloc] init];
        self.auth.clientToken = [FMSession clientToken];
        self.auth.clientSecret = [FMSession clientSecret];
        FMAPIRequest *cuuidRequest = [FMAPIRequest requestCUUID];
        cuuidRequest.successBlock = ^(NSDictionary *result) {
            NSString *cuuid = result[@"client_id"];
            if([cuuid isKindOfClass:[NSString class]] && ![cuuid isEqualToString:@""]) {
                self.auth.cuuid = cuuid;
                [self updateServerTime];
                [self storeAuthToDisk];
            }
        };
        cuuidRequest.failureBlock = ^(NSError *error) {
            NSLog(@"ERROR: FeedMedia failed to obtain cuuid: %@",error);
        };
        [cuuidRequest send];
    }
    return self.auth;
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
    auth.clientToken = [FMSession clientToken];
    auth.clientSecret = [FMSession clientSecret];
    return auth;
}

#pragma mark - STATIONS

- (void)requestStations {
    FMAPIRequest *stationRequest = [FMAPIRequest requestStationsForPlacement:self.placementId];
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

- (void)stationRequestSucceeded:(NSArray *)stationJSON {
    NSArray *stations = nil; //todo: process stationJSON & validate
    if(self.delegate && [self.delegate respondsToSelector:@selector(session:didReceiveStations:)]) {
        [self.delegate session:self didReceiveStations:stations];
    }
}

- (void)stationRequestFailed:(NSError *)error {
    if(self.delegate && [self.delegate respondsToSelector:@selector(session:didFailToReceiveStations:)]) {
        [self.delegate session:self didFailToReceiveStations:error];
    }
}

- (void)setStation:(FMStation *)station {
    self.currentStationId = station.identifier;
}

- (void)setStationWithId:(NSString *)stationId {
    self.currentStationId = stationId;
}

#pragma mark - PLAYBACK

- (void)requestNextTrack {
    FMAPIRequest *trackRequest = [FMAPIRequest requestPlayInPlacement:self.placementId withStation:self.currentStationId];
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

- (void)sendRequest:(FMAPIRequest *)request {
    if(request.authRequired) {
        request.auth = self.auth;
    }
    [request send];
}

@end
