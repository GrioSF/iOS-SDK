//
//  FMBandwidthMonitor.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMBandwidthMonitor.h"
#import "FMLog.h"

#define kFMDefaultBandwidthRecheckInterval 2.0  //seconds between checks
#define kFMBandwidthDurationFudgeFactor 1.0     //consider load complete if within fudge factor seconds of playback

@interface FMBandwidthMonitor () {
    double _estimatedDownloadRate;  // Unitless measure (seconds playback / seconds elapsed)
    BOOL _loadingComplete;
    BOOL _playbackLikelyToKeepUp;
    NSTimeInterval _lastPlayableDuration;

    NSTimer *_networkCheckTimer;
}
@end

@implementation FMBandwidthMonitor

- (id)init {
    if(self = [super init]) {
        _estimatedDownloadRate = 0;
        _refreshRate = kFMDefaultBandwidthRecheckInterval;
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

// !!!: loadedDuration Issues
/* If the asset isn't being played, loadedTimeRanges appears to stay empty for a while and then suddenly jumps up, which throws off the calculation. Works as expected if the asset is playing, but it's not reliable if paused or preloading.
 */
- (NSTimeInterval)loadedDuration {
    NSArray *timeRanges = self.monitoredItem.loadedTimeRanges;
    CMTimeRange totalRange = kCMTimeRangeZero;
    for(NSValue *rangeValue in timeRanges) {
        totalRange = CMTimeRangeGetUnion(totalRange, [rangeValue CMTimeRangeValue]);
    }
    CMTime endTime = CMTimeRangeGetEnd(totalRange);
    return MAX(0,CMTimeGetSeconds(endTime));
}

- (void)start {
    _estimatedDownloadRate = 0;
    _lastPlayableDuration = [self loadedDuration];

    [_networkCheckTimer invalidate];
    if(_monitoredItem) {
        _networkCheckTimer = [NSTimer scheduledTimerWithTimeInterval:self.refreshRate target:self selector:@selector(networkCheckTimerFired:) userInfo:nil repeats:YES];
    }
}

- (void)stop {
    [_networkCheckTimer invalidate];
    _networkCheckTimer = nil;
}

- (void)notifyDelegate {
    if([self.delegate respondsToSelector:@selector(bandwidthMonitorDidUpdate:)]) {
        [self.delegate bandwidthMonitorDidUpdate:self];
    }
}

- (BOOL)itemIsValid {
    return self.monitoredItem.asset != nil &&
    CMTimeGetSeconds(self.monitoredItem.duration) > 0;
}

- (void)networkCheckTimerFired:(NSTimer *)timer {

    if(![self itemIsValid]) {
        //don't update the estimate, but keep firing the timer in case playback resumes/preload finishes/etc
        return;
    }

    //estimate download rate with weighted average of (old rate) and (new rate) (poor man's lowpass filter)
    NSTimeInterval loadedDuration = [self loadedDuration];
    _estimatedDownloadRate = (_estimatedDownloadRate + .5*(loadedDuration - _lastPlayableDuration)/self.refreshRate)/1.5;
    _lastPlayableDuration = loadedDuration;
    FMLogDebug(@"Calculated download rate: %f",_estimatedDownloadRate);
    FMLogDebug(@"Calculated download kbps: %f",self.currentDownloadRate);
    if(self.loadingComplete) {
        [self stop];
    }
    
    [self notifyDelegate];
}

- (double)currentDownloadRate {
    NSArray *accessEvents = self.monitoredItem.accessLog.events;
    AVPlayerItemAccessLogEvent *lastEvent = [accessEvents lastObject];
    double bitrate = lastEvent.observedBitrate / 1024;

    if(bitrate > 0) {
        return _estimatedDownloadRate * bitrate;
    }
    else {
        return -1;
    }
}

- (BOOL)playbackLikelyToKeepUp {
    FMLogDebug(@"Checking %f >= 1.0", _estimatedDownloadRate);
    if (_estimatedDownloadRate >= 1.0) return YES;

    NSTimeInterval durationLeftToPlay = CMTimeGetSeconds(CMTimeSubtract(self.monitoredItem.duration, self.monitoredItem.currentTime));
    NSTimeInterval durationLeftToDownload = CMTimeGetSeconds(self.monitoredItem.duration) - [self loadedDuration];
    NSTimeInterval estimatedTimeRequired = durationLeftToDownload / _estimatedDownloadRate;

    FMLogDebug(@"Checking %f < %f || %f < %f", estimatedTimeRequired, durationLeftToPlay, durationLeftToPlay, kFMBandwidthDurationFudgeFactor);

    return estimatedTimeRequired < durationLeftToPlay || durationLeftToPlay < kFMBandwidthDurationFudgeFactor;
}

- (BOOL)loadingComplete {
    NSTimeInterval amountLeftToDownload = CMTimeGetSeconds(self.monitoredItem.duration) - [self loadedDuration];
    return amountLeftToDownload <= MAX(kFMBandwidthDurationFudgeFactor, _estimatedDownloadRate*self.refreshRate);
}

@end

#undef kFMDefaultBandwidthRecheckInterval
