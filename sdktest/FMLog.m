//
//  FMLog.m
//  sdktest
//
//  Created by James Anthony on 10/1/12.
//  Copyright (c) 2012 Feed Media Inc. All rights reserved.
//

#import "FMLog.h"

static FMLogLevel fm_currentLogLevel = FMLogLevelError;

void FMLogSetLevel(FMLogLevel level) {
    fm_currentLogLevel = level;
}

void _FMLog(NSInteger level, NSString *fmt, ...) {
    if(level <= fm_currentLogLevel) {
        va_list varPtr;
        va_start(varPtr,fmt);
        NSLogv(fmt, varPtr);
        va_end(varPtr);
    }
}