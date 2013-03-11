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

#define kFMAuthStoragePath @"FeedMedia/"
#define kFMAuthStorageName @"FMAuth.plist"


@interface FMSession () {
}
@property (nonatomic) NSString *clientToken;
@property (nonatomic) NSString *clientSecret;
@property (nonatomic) FMAuth *auth;
@end

@implementation FMSession

+ (FMSession *)sessionWithClientToken:(NSString *)token secret:(NSString *)secret {
    return [[FMSession alloc] initWithClientToken:token secret:secret];
}

- (id)initWithClientToken:(NSString *)token secret:(NSString *)secret {
    if(self = [super init]) {
        _clientToken = token;
        _clientSecret = secret;
    }
    if(self.clientToken == nil || [self.clientToken isEqualToString:@""] || self.clientSecret == nil || [self.clientSecret isEqualToString:@""]) {
        NSLog(@"ERROR: FMSession must be initialized with a token and secret");
        return nil;
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

- (FMAuth *)auth {
    if(self.auth == nil) {
        self.auth = [self authFromDisk];
    }
    if(self.auth == nil) {
        self.auth = [[FMAuth alloc] init];
        //need cuuid + timestamp
    }
    self.auth.clientToken = self.clientToken;
    self.auth.clientSecret = self.clientSecret;
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
    return [[FMAuth alloc] initWithCoder:unarchiver];
}

#pragma mark - STATIONS

- (void)requestStationsForPlacement:(NSString *)placementId {
    FMAPIRequest *stationRequest = [FMAPIRequest requestStationsForPlacement:placementId];
    stationRequest.successBlock = ^(id stationJSON) {
        [self stationRequestSucceeded:stationJSON];
    };
    stationRequest.failureBlock = ^(NSError *error) {
        [self stationRequestFailed:error];
    };
    [self sendRequest:stationRequest];
}

- (void)stationRequestSucceeded:(id)stationJSON {
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
    FMAPIRequest *trackRequest = [FMAPIRequest requestPlayInStation:self.currentStationId];
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
