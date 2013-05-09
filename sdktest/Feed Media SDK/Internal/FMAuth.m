//
//  FMAuth.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMAuth.h"
#import <CommonCrypto/CommonCrypto.h>
#import "FMAPIRequest.h"
#import "FMBase64.h"
#import "FMLog.h"

#define kFMNonceabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
#define kFMNonceabetLength 62
#define kFMNonceLength 10

static inline NSString *FM_URLEncodeString(NSString *string) {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                 (CFStringRef)string,
                                                                                 NULL,
                                                                                 CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                 kCFStringEncodingUTF8));
}

static inline NSString *FM_URLDecodeString(NSString *string) {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                                 (CFStringRef)string,
                                                                                                 CFSTR(""),
                                                                                                 kCFStringEncodingUTF8));
}

#pragma mark - FMKVPair - Helper class for sorting parameters

@interface FMKVPair : NSObject
@property NSString *k;
@property NSString *v;
+ (NSArray *)sortedPairsWithDictionary:(NSDictionary *)dictionary;
+ (FMKVPair *)pairWithKey:(NSString *)key value:(NSString *)value;
+ (FMKVPair *)threewayMin:(FMKVPair *)pair1 with:(FMKVPair *)pair2 and:(FMKVPair *)pair3;
@end
@implementation FMKVPair

+ (NSArray *)sortedPairsWithDictionary:(NSDictionary *)dictionary {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[dictionary count]];
    for(NSString *key in dictionary) {
        if(key != nil) {
            [array addObject:[FMKVPair pairWithKey:FM_URLEncodeString(key)
                                             value:FM_URLEncodeString(dictionary[key])]];
        }
    }
    return [array sortedArrayUsingSelector:@selector(compare:)];

}

+ (FMKVPair *)pairWithKey:(NSString *)key value:(NSString *)value {
    FMKVPair *pair = [[FMKVPair alloc] init];
    pair.k = key;
    pair.v = value;
    return pair;
}

- (NSComparisonResult)compare:(FMKVPair *)pair2 {
    if(![pair2 isKindOfClass:[FMKVPair class]]) return NSOrderedAscending;
    NSComparisonResult result = [self.k compare:pair2.k options:NSLiteralSearch];
    if(result == NSOrderedSame) {
        result = [self.v compare:pair2.v options:NSLiteralSearch];
    }
    return result;
}

+ (FMKVPair *)threewayMin:(FMKVPair *)pair1 with:(FMKVPair *)pair2 and:(FMKVPair *)pair3 {
    if(pair1 == nil && pair2 == nil && pair3 == nil) return nil;
    if(pair2 == nil && pair3 == nil) return pair1;
    if(pair1 == nil && pair3 == nil) return pair2;
    if(pair1 == nil && pair2 == nil) return pair3;
    if(pair1 == nil) {
        NSComparisonResult comparison = [pair2 compare:pair3];
        return (comparison == NSOrderedAscending ? pair2 : pair3);
    }
    if(pair2 == nil) {
        NSComparisonResult comparison = [pair1 compare:pair3];
        return (comparison == NSOrderedAscending ? pair1 : pair3);
    }
    if(pair3 == nil) {
        NSComparisonResult comparison = [pair1 compare:pair2];
        return (comparison == NSOrderedAscending ? pair1 : pair2);
    }

    NSComparisonResult comparison12 = [pair1 compare:pair2];
    if(comparison12 == NSOrderedAscending) {
        NSComparisonResult comparison13 = [pair1 compare:pair3];
        return (comparison13 == NSOrderedAscending ? pair1 : pair3);
    }
    else {
        NSComparisonResult comparison23 = [pair2 compare:pair3];
        return (comparison23 == NSOrderedAscending ? pair2 : pair3);
    }
}

@end

#pragma mark - FMAUTH

@implementation FMAuth

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.timeOffset forKey:@"timeOffset"];
    [encoder encodeObject:self.cuuid forKey:@"cuuid"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if(self = [super init]) {
        self.timeOffset = [decoder decodeObjectForKey:@"timeOffset"];
        self.cuuid = [decoder decodeObjectForKey:@"cuuid"];
    }
    return self;
}

- (void)setCurrentServerTime:(NSTimeInterval)unixTime {
    self.timeOffset = @(unixTime - [[NSDate date] timeIntervalSince1970]);
}

+ (BOOL)isValidString:(NSString *)string {
    return string != nil && ![string isEqualToString:@""];
}

- (NSURLRequest *)authenticatedURLRequest:(FMAPIRequest *)request {
    FMLogDebug(@"Authenticating request using token/secret/cuuid %@/%@/%@",self.clientToken,self.clientSecret,self.cuuid);

    if(![FMAuth isValidString:self.clientToken] || ![FMAuth isValidString:self.clientSecret]) {
        return nil;
    }
    if([FMAuth isValidString:self.cuuid]) {
        if([request.httpMethod isEqualToString:@"POST"]) {
            request.postParameters[@"client_id"] = self.cuuid;
        }
        else {
            request.queryParameters[@"client_id"] = self.cuuid;
        }
    }
    NSDictionary *oauthHeaders = [self oauthHeaders];   //NOTE: this generates nonce & timestamp
    NSString *signatureBaseString = [self signatureBaseString:request withOAuthHeaders:oauthHeaders];
    FMLogDebug(@"Generated SBS: %@",signatureBaseString);
    NSString *key = [NSString stringWithFormat:@"%@&",FM_URLEncodeString(self.clientSecret)];
    NSData *hash = HMAC_SHA256(key, signatureBaseString);
    NSString *base64hash = [FMBase64 base64EncodedStringFromData:hash];
    NSMutableString *oauthString = [[NSMutableString alloc] init];
    [oauthString appendString:@"OAuth realm=\"Feed.fm\","];
    for(NSString *key in oauthHeaders) {
        [oauthString appendFormat:@"%@=\"%@\",",key,oauthHeaders[key]];
    }
    [oauthString appendFormat:@"oauth_signature=\"%@\"",FM_URLEncodeString(base64hash)];
    NSMutableURLRequest *urlRequest = [[request urlRequest] mutableCopy];
    [urlRequest addValue:oauthString forHTTPHeaderField:@"Authorization"];

    FMLogDebug(@"Returning urlRequest: %@\nHeaders: %@", urlRequest,[urlRequest allHTTPHeaderFields]);
    return urlRequest;
}

- (NSString *)parameterStringForRequest:(FMAPIRequest *)apiRequest withOAuthHeaders:(NSDictionary *)oauthParams {
    NSMutableString *parameterString = [NSMutableString string];
    NSDictionary *queryParams = apiRequest.queryParameters;
    NSDictionary *postParams = apiRequest.postParameters;

    NSArray *oauthPairs = [FMKVPair sortedPairsWithDictionary:oauthParams];
    NSArray *queryPairs = [FMKVPair sortedPairsWithDictionary:queryParams];
    NSArray *postPairs  = [FMKVPair sortedPairsWithDictionary:postParams];

    NSUInteger oauthIndex = 0, queryIndex =0, postIndex = 0;
    BOOL oauthRemains = oauthIndex < [oauthPairs count];
    BOOL queryRemains = queryIndex < [queryPairs count];
    BOOL postRemains =  postIndex < [postPairs count];
    while(1) {

        FMKVPair *nextPair = [FMKVPair threewayMin:(oauthRemains ? oauthPairs[oauthIndex] : nil)
                                              with:(queryRemains ? queryPairs[queryIndex] : nil)
                                               and:(postRemains ? postPairs[postIndex] : nil)];
        if(nextPair == nil) {
            break;
        }

        if(oauthRemains && nextPair == oauthPairs[oauthIndex]) {
            oauthIndex++;
            oauthRemains = oauthIndex < [oauthPairs count];
        }
        if(queryRemains && nextPair == queryPairs[queryIndex]) {
            queryIndex++;
            queryRemains = queryIndex < [queryPairs count];
        }
        if(postRemains && nextPair == postPairs[postIndex]) {
            postIndex++;
            postRemains =  postIndex < [postPairs count];
        }

        [parameterString appendFormat:@"&%@=%@",nextPair.k,nextPair.v];
    }
    return FM_URLEncodeString([parameterString substringFromIndex:1]); //substring call removes leading '&'
}

- (NSDictionary *)oauthHeaders {
    return @{
             @"oauth_consumer_key" : self.clientToken,
             @"oauth_nonce" : [self generateNonce],
             @"oauth_timestamp" : [self timestamp],
             @"oauth_version" : @"1.0",
             @"oauth_signature_method" : @"HMAC-SHA256"
             };
}

- (NSString *)signatureBaseString:(FMAPIRequest *)apiRequest withOAuthHeaders:(NSDictionary *)oauthHeaders {

    NSMutableURLRequest *urlRequest = [[apiRequest urlRequest] mutableCopy];
    NSString *method = [urlRequest.HTTPMethod uppercaseString];
    NSString *portString = @"";
    NSInteger port = [urlRequest.URL.port integerValue];
    if((port == 80 && [urlRequest.URL.scheme caseInsensitiveCompare:@"http"] != NSOrderedSame) ||
       (port == 443 && [urlRequest.URL.scheme caseInsensitiveCompare:@"https"] != NSOrderedSame) ) {
        portString = [NSString stringWithFormat:@":%i",port];
    }
    NSString *normalizedUrl = [NSString stringWithFormat:@"%@://%@%@%@",
                               [urlRequest.URL.scheme lowercaseString],
                               [urlRequest.URL.host lowercaseString],
                               portString,
                               urlRequest.URL.path];
    normalizedUrl = FM_URLEncodeString(normalizedUrl);

    return [NSString stringWithFormat:@"%@&%@&%@",method,normalizedUrl,[self parameterStringForRequest:apiRequest withOAuthHeaders:oauthHeaders]];
}

#pragma mark - Crypto

NSData *HMAC_SHA256(NSString *key, NSString *data)
{
    const char *cKey  = [key cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    return [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
}

#pragma mark - Utility

- (NSString *)generateNonce {
////DEBUG:
//    return @"k320wtrzfr";

    NSMutableString *nonce = [NSMutableString stringWithCapacity:kFMNonceLength];
    for(int i = 0; i< kFMNonceLength; i++) {
        [nonce appendFormat:@"%c",kFMNonceabet[arc4random_uniform(strlen(kFMNonceabet))]];
    }
    return nonce;
}

- (long)serverTime {
    return (long)([[NSDate date] timeIntervalSince1970] + [self.timeOffset doubleValue]);
}

- (NSString *)timestamp {
////DEBUG:
//    return @"1363799128";

    long time = [self serverTime];
    return [NSString stringWithFormat:@"%li",time];
}

@end