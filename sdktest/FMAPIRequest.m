//
//  FMAPIRequest.m
//  sdktest
//
//  Created by James Anthony on 3/11/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMAPIRequest.h"
#import "FMError.h"
#import "FMLog.h"

#define kFeedAPILocation @"http://feed.fm/api/v2/"
#define kFeedSDKVersion @"1.0"
#define kFeedRequestDefaultRetryCount 3

@interface FMAPIRequest () {

}

@property NSString *httpMethod;
@property NSString *httpEndpoint;
@property NSInteger retryCount;
@property NSMutableDictionary *postParameters;
@property NSMutableDictionary *queryParameters;
@property BOOL authRequired;
@property NSDictionary *result;
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

+ (FMAPIRequest *)requestPlayInPlacement:(NSString *)placementId {
    return [self requestPlayInPlacement:placementId withStation:nil];
}

+ (FMAPIRequest *)requestPlayInPlacement:(NSString *)placementId withStation:(NSString *)stationId {
    return [self requestPlayInPlacement:placementId
                            withStation:stationId
                                formats:nil
                             maxBitrate:nil];
}

+ (FMAPIRequest *)requestPlayInPlacement:(NSString *)placementId
                             withStation:(NSString *)stationId
                                 formats:(NSString *)formatList
                              maxBitrate:(NSNumber *)bitrate {
    if(placementId == nil || [placementId isEqualToString:@""]) {
        FMLogError(@"ERROR: placementId must not be nil");
        return nil;
    }
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"POST";
    request.httpEndpoint = @"play";
    request.postParameters[@"placement_id"] = placementId;
    if(stationId && ![stationId isEqualToString:@""]) {
        request.postParameters[@"station_id"] = stationId;
    }
    if(formatList && ![formatList isEqualToString:@""]) {
        request.postParameters[@"formats"] = formatList;
    }
    if(bitrate && [bitrate integerValue] > 0) {
        request.postParameters[@"max_bitrate"] = [NSString stringWithFormat:@"%li",(long)[bitrate integerValue]];
    }
    request.authRequired = YES;
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
    return [self requestSkip:playId elapsed:-1];
}

+ (FMAPIRequest *)requestSkip:(NSString *)playId elapsed:(NSTimeInterval)elapsedTime {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"POST";
    request.httpEndpoint = [NSString stringWithFormat:@"play/%@/skip",playId];

    if(elapsedTime > 0) {
        request.postParameters[@"seconds"] = [NSString stringWithFormat:@"%f", elapsedTime];
    }
    request.authRequired = YES;
    return request;
}

+ (FMAPIRequest *)requestInvalidate:(NSString *)playId {
    FMAPIRequest *request = [[FMAPIRequest alloc] init];
    request.httpMethod = @"POST";
    request.httpEndpoint = [NSString stringWithFormat:@"play/%@/invalidate",playId];
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
    NSString *encodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                             (CFStringRef)string,
                                                                                             NULL,
                                                                                             CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                             kCFStringEncodingUTF8));
	return encodedString;
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
        self.queryParameters = [[NSMutableDictionary alloc] init];
        self.retryCount = kFeedRequestDefaultRetryCount;
    }
    return self;
}

- (void)cancel {
    self.successBlock = nil;
    self.failureBlock = nil;
}

- (void)failWithError:(NSError *)error {
    FMLogDebug(@"Request failing with error: %@", error);
    self.error = error;
    if(self.failureBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.failureBlock(error);
        });
    }
}

- (void)succeedWithResult:(NSDictionary *)result {
    self.result = result;
    if(self.successBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.successBlock(result);
        });
    }
}

- (NSString *)queryString {
    if([self.queryParameters count] == 0) {
        return @"";
    }
    else  {
        NSMutableString *queryString = [[NSMutableString alloc] init];
        for(NSString *key in self.queryParameters) {
            [queryString appendString:[NSString stringWithFormat:@"&%@=%@",key,self.queryParameters[key]]];
        }
        return [queryString stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@"?"];  //convert leading '&'
    }
}

- (NSURLRequest *)urlRequest {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@",kFeedAPILocation,self.httpEndpoint,[self queryString]]];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = self.httpMethod;
    if([self.httpMethod isEqualToString:@"POST"]) {
        [urlRequest setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        if([self.postParameters count] > 0) {
            [urlRequest setHTTPBody:[[FMAPIRequest stringFromParameters:self.postParameters] dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    else if([self.httpMethod isEqualToString:@"GET"]) {
        [urlRequest setValue: @"text/text; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    }
    else {
        FMLogWarn(@"Warning: Unexpected http method: %@",self.httpMethod);
    }
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [urlRequest setValue:[FMAPIRequest userAgent] forHTTPHeaderField:@"User-Agent"];

    return urlRequest;
}

- (NSError *)errorFromJSON:(id)json {
    if(json == nil || ![json isKindOfClass:[NSDictionary class]]) {
        return [NSError errorWithDomain:FMAPIErrorDomain code:FMErrorCodeUnexpectedReturnType userInfo:nil];
    }
    else if(([json[@"success"] isKindOfClass:[NSNumber class]] && [(NSNumber *)json[@"success"] boolValue] == YES) ||
            ([json[@"success"] isKindOfClass:[NSString class]] && [(NSString *)json[@"success"] isEqualToString:@"true"])) {
        return nil;
    }
    else {
        NSNumber *code = json[@"error"][@"code"];
        NSString *message = json[@"error"][@"message"];
        NSDictionary *errorInfo = nil;
        if([message isKindOfClass:[NSString class]]) {
            errorInfo = @{NSLocalizedDescriptionKey : message};
        }
        return [NSError errorWithDomain:FMAPIErrorDomain code:[code integerValue] userInfo:errorInfo];
    }
}

- (BOOL)shouldRetryAfterResponse:(NSHTTPURLResponse *)response error:(NSError *)error {
    BOOL hasRetriesLeft = self.retryCount > 0;
    BOOL isRecoverable = ([response isKindOfClass:[NSHTTPURLResponse class]] && response.statusCode == 408) ||
                         ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorTimedOut);
    
    return hasRetriesLeft && isRecoverable;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: %@",[super description], [self httpEndpoint]];
}

- (void)send {
    NSURLRequest *urlRequest = nil;
    if(self.authRequired) {
        FMLogDebug(@"Trying to send request with auth: %@", self.auth);
        urlRequest = [self.auth authenticatedURLRequest:self];
        if(urlRequest == nil) {
            FMLogError(@"ERROR: Tried to send API Request but no authentication available: %@", self);
            [self failWithError:[NSError errorWithDomain:FMAPIErrorDomain code:FMErrorCodeInvalidCredentials userInfo:nil]];
            return;
        }
    }
    else {
        urlRequest = [self urlRequest];
    }
    FMLogDebug(@"Sending request with endpoint, body: %@\n%@",urlRequest.URL.absoluteString,[[NSString alloc] initWithData:urlRequest.HTTPBody encoding:NSUTF8StringEncoding]);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSHTTPURLResponse *response = nil;
        NSError *connectionError = nil;
        NSError *jsonError = nil;
        id jsonObject = nil;

        NSData *resultData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&connectionError];

        if(resultData && [resultData length] > 0) {
            jsonObject = [NSJSONSerialization JSONObjectWithData:resultData options:0 error:&jsonError];
        }
        else if([self shouldRetryAfterResponse:response error:connectionError]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.retryCount--;
                [self send];
            });
            return;
        }
        else {
            NSDictionary *errorInfo = nil;
            if(connectionError) {
                errorInfo = @{NSUnderlyingErrorKey : connectionError};
            }
            [self failWithError:[NSError errorWithDomain:FMAPIErrorDomain code:FMErrorCodeRequestFailed userInfo:errorInfo]];
            return;
        }

        if(jsonError != nil) {
            [self failWithError:[NSError errorWithDomain:FMAPIErrorDomain code:FMErrorCodeUnexpectedReturnType userInfo:@{NSUnderlyingErrorKey : jsonError}]];
            return;
        }
        if(![jsonObject isKindOfClass:[NSDictionary class]]) {
            [self failWithError:[NSError errorWithDomain:FMAPIErrorDomain code:FMErrorCodeUnexpectedReturnType userInfo:nil]];
        }
        
        NSError *apiError = [self errorFromJSON:jsonObject];
        if(apiError) {
            //TODO: Try to recover from timestamp error?
            [self failWithError:apiError];
        }
        else {
            [self succeedWithResult:jsonObject];
        }
    });
}

@end
