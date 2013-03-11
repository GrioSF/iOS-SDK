//
//  FMAPIRequest.m
//  sdktest
//
//  Created by James Anthony on 3/11/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMAPIRequest.h"

#define kFeedAPILocation @"http://feed.fm/api/v2/"
#define kFeedSDKVersion @"1.0"

@interface FMAPIRequest () {

}

@property NSString *httpMethod;
@property NSString *httpEndpoint;
@property NSMutableDictionary *postParameters;
@property BOOL authRequired;
@property id result;
@property NSError *error;

@end

@implementation FMAPIRequest

+ (FMAPIRequest *)requestCUUID {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"POST";
    request.httpEndpoint = @"client";
    request.authRequired = YES;
    return request;
}

+ (FMAPIRequest *)requestServerTime {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"GET";
    request.httpEndpoint = @"oauth/time";
    request.authRequired = NO;
    return request;
}

+ (FMAPIRequest *)requestStationsForPlacement:(NSString *)placementId {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"GET";
    request.httpEndpoint = [NSString stringWithFormat:@"placement/%@/station",placementId];
    request.authRequired = YES;
    return request;
}

+ (FMAPIRequest *)requestPlay {
    return [self requestPlayInStation:nil];
}

+ (FMAPIRequest *)requestPlayInStation:(NSString *)stationId {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"POST";
    request.httpEndpoint = @"play";
    request.authRequired = YES;
    //  NEEDS POST PARAMETERS placement_id, client_id, station_id (if not nil)
    return request;
}

+ (FMAPIRequest *)requestStart:(NSString *)playId {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"POST";
    request.httpEndpoint = [NSString stringWithFormat:@"play/%@/start",playId];
    request.authRequired = YES;
    return request;
}

+ (FMAPIRequest *)requestElapse:(NSString *)playId time:(NSTimeInterval)elapsedTime {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"POST";
    request.httpEndpoint = [NSString stringWithFormat:@"play/%@/elapse",playId];
    request.postParameters[@"seconds"] = [NSString stringWithFormat:@"%f", elapsedTime];
    request.authRequired = YES;
    return request;
}

+ (FMAPIRequest *)requestSkip:(NSString *)playId {
    return [self requestSkip:playId force:NO elapsed:-1];
}

+ (FMAPIRequest *)requestSkip:(NSString *)playId force:(BOOL)force elapsed:(NSTimeInterval)elapsedTime {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"POST";
    request.httpEndpoint = [NSString stringWithFormat:@"play/%@/skip",playId];
    if(force) {
        request.postParameters[@"force"] = @(1);
    }
    if(elapsedTime > 0) {
        request.postParameters[@"seconds"] = [NSString stringWithFormat:@"%f", elapsedTime];
    }
    request.authRequired = YES;
    return request;
}

+ (FMAPIRequest *)requestComplete:(NSString *)playId {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"POST";
    request.httpEndpoint = [NSString stringWithFormat:@"play/%@/complete",playId];
    request.authRequired = YES;
    return request;
}

+ (NSString *)userAgent {
    return [NSString stringWithFormat:@"FeedMediaSDK/%@ (%@; %@; %@; %@)",
            kFeedSDKVersion,
            [[UIDevice currentDevice] model],
            [[UIDevice currentDevice] systemName],
            [[UIDevice currentDevice] systemVersion],
            [[NSLocale currentLocale] localeIdentifier]];
}

+ (NSString *)URLEncodeString:(NSString *)string {
    NSString *result = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                             (CFStringRef)string,
                                                                                             NULL,
                                                                                             CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                             kCFStringEncodingUTF8));
	return result;
}

+ (NSString *)stringFromParameters:(NSDictionary *)parameters {
    if([parameters count] == 0) {
        return @"";
    }
    NSMutableString *parameterString = [[NSMutableString alloc] init];
    for(NSString *key in parameters) {
        [parameterString appendFormat:@"%@=%@&",[self URLEncodeString:key],[self URLEncodeString:parameters[key]]];
    }
    [parameterString replaceCharactersInRange:NSMakeRange([parameterString length]-1, 1) withString:@""];   //remove trailing '&'
    return parameterString;
}


- (id)init {
    if(self = [super init]) {
        self.postParameters = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)failWithError:(NSError *)error {
    self.error = error;
    if(self.failureBlock) {
        self.failureBlock(error); //todo: do we need to call this on a particular thread, or will the request take care of it?
    }
}

- (void)succeedWithResult:(id)result {
    self.result = result;
    if(self.successBlock) {
        self.successBlock(result); //todo: do we need to call this on a particular thread, or will the request take care of it?
    }
}

- (NSURLRequest *)urlRequest {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",kFeedAPILocation,self.httpEndpoint]];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = self.httpMethod;
    if([self.httpMethod isEqualToString:@"POST"]) {
        [urlRequest setValue:@"application/x-www-form-urlencoded charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        if([self.postParameters count] > 0) {
            [urlRequest setHTTPBody:[[FMAPIRequest stringFromParameters:self.postParameters] dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    else if([self.httpMethod isEqualToString:@"GET"]) {
        [urlRequest setValue: @"text/text" forHTTPHeaderField:@"Content-Type"];
    }
    else {
        NSLog(@"Warning: Unexpected http method: %@",self.httpMethod);
    }
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [urlRequest setValue:[FMAPIRequest userAgent] forHTTPHeaderField:@"User-Agent"];

    return urlRequest;
}

- (void)send {
    NSURLRequest *urlRequest = nil;
    if(self.authRequired) {
        urlRequest = [self.auth authenticatedURLRequest:self];
        if(urlRequest == nil) {
            NSLog(@"ERROR: Tried to send API Request but no authentication available: %@", self);
            NSError *error = nil; //todo: Create NSError with appropriate codes
            [self failWithError:error];
            return;
        }
    }
    else {
        urlRequest = [self urlRequest];
    }

    //todo: fire request
}

@end
