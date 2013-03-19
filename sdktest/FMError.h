//
//  FMError.h
//  sdktest
//
//  Created by James Anthony on 3/12/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

extern NSString * const FMAPIErrorDomain;

typedef enum FMErrorCode : NSInteger {
    FMErrorCodeRequestFailed = -4,
    FMErrorCodeUnexpectedReturnType = -1,
    FMErrorCodeGeoBlocked = 1,
    FMErrorCodeInvalidCredentials = 5,
    FMErrorCodeAccessForbidden = 6,
    FMErrorCodeSkipLimitExceeded = 7,
    FMErrorCodeNoAvailableMusic = 9,
    FMErrorCodeInvalidSkip = 12,
    FMErrorCodeInvalidParameter = 15,
    FMErrorCodeMissingParameter = 16,
    FMErrorCodeNoSuchResource = 17,
    FMErrorCodeInternal = 18
} FMErrorCode;
