//
//  FMAuth.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMAPIRequest.h"

@interface FMAuth : NSObject <FMAuthenticator, NSCoding>

@property NSNumber *timeOffset;
@property NSString *clientToken;
@property NSString *clientSecret;
@property NSString *cuuid;

- (void) setCurrentServerTime:(NSTimeInterval)unixTime; //triggers timeOffset update

@end
