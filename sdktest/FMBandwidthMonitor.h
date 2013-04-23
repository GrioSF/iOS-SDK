//
//  FMBandwidthMonitor.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class FMBandwidthMonitor;

@protocol FMBandwidthMonitorDelegate <NSObject>
@optional
- (void)bandwidthMonitorDidUpdate:(FMBandwidthMonitor *)monitor;
@end

@interface FMBandwidthMonitor : NSObject

@property (nonatomic, weak) id<FMBandwidthMonitorDelegate> delegate;
@property (nonatomic, weak) AVPlayerItem *monitoredItem;
@property (nonatomic) NSTimeInterval refreshRate;
@property (nonatomic, readonly) BOOL playbackLikelyToKeepUp;
@property (nonatomic, readonly) BOOL loadingComplete;
@property (nonatomic, readonly) double currentDownloadRate; //returns -1 if unknown

- (void)start;
- (void)stop;

@end
