//
//  FMAPIRequest.h
//  sdktest
//
//  Created by James Anthony on 3/11/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMAPIRequest;

@protocol FMAuthenticator <NSObject>
- (NSURLRequest *)authenticatedURLRequest:(FMAPIRequest *)request;
@end

@interface FMAPIRequest : NSObject

@property (nonatomic, assign) id<FMAuthenticator> auth;
@property (nonatomic, copy) void (^successBlock)(id);
@property (nonatomic, copy) void (^failureBlock)(NSError *);
@property (readonly) NSURLRequest *urlRequest;
@property (readonly) BOOL authRequired;
@property (readonly) NSMutableDictionary *postParameters;
@property (readonly) NSMutableDictionary *queryParameters;

+ (FMAPIRequest *)requestCUUID;
+ (FMAPIRequest *)requestServerTime;
+ (FMAPIRequest *)requestStationsForPlacement:(NSString *)placementId;
+ (FMAPIRequest *)requestPlay;
+ (FMAPIRequest *)requestPlayInStation:(NSString *)stationId;
+ (FMAPIRequest *)requestStart:(NSString *)playId;
+ (FMAPIRequest *)requestElapse:(NSString *)playId time:(NSTimeInterval)elapsedTime;
+ (FMAPIRequest *)requestSkip:(NSString *)playId;
+ (FMAPIRequest *)requestSkip:(NSString *)playId force:(BOOL)force elapsed:(NSTimeInterval)elapsedTime;
+ (FMAPIRequest *)requestComplete:(NSString *)playId;

- (void)send;

@end