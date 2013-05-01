//
//  FMReachability.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//  Contains code copyright (c) 2011 Apple Inc. from the sample code Reachability
//

#import "FMReachability.h"
#import <sys/socket.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <CoreFoundation/CoreFoundation.h>

NSString *const FMReachabilityChangedNotification = @"FMNetworkReachabilityChangedNotification";

@interface FMReachability () {
    BOOL localWiFiRef;
	SCNetworkReachabilityRef reachabilityRef;
}
@end

@implementation FMReachability

static void FMReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
	//We're on the main RunLoop, so an NSAutoreleasePool is not necessary, but is added defensively
	// in case someon uses the Reachablity object in a different thread.
    @autoreleasepool {
        FMReachability *noteObject = (__bridge FMReachability *)info;
        // Post a notification to notify the client that the network reachability changed.
        [[NSNotificationCenter defaultCenter] postNotificationName:FMReachabilityChangedNotification object: noteObject];
    }
}

- (BOOL)startNotifier {
	BOOL retVal = NO;
	SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
	if(SCNetworkReachabilitySetCallback(reachabilityRef, FMReachabilityCallback, &context)) {
		if(SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
			retVal = YES;
		}
	}
	return retVal;
}

- (void)stopNotifier {
	if(reachabilityRef != NULL) {
		SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}
}

- (void) dealloc {
	[self stopNotifier];
	if(reachabilityRef != NULL) {
		CFRelease(reachabilityRef);
	}
}

#pragma mark - Factory Methods

+ (FMReachability*)reachabilityWithHostName:(NSString*)hostName {
	FMReachability* retVal = NULL;
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
	if(reachability!= NULL) {
		retVal= [[self alloc] init];
		if(retVal != NULL) {
			retVal->reachabilityRef = reachability;
			retVal->localWiFiRef = NO;
		}
	}
	return retVal;
}

+ (FMReachability*)reachabilityWithAddress:(const struct sockaddr_in*)hostAddress {
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)hostAddress);
	FMReachability* retVal = NULL;
	if(reachability != NULL) {
		retVal= [[self alloc] init];
		if(retVal!= NULL) {
			retVal->reachabilityRef = reachability;
			retVal->localWiFiRef = NO;
		}
	}
	return retVal;
}

+ (FMReachability*)reachabilityForInternetConnection {
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
	return [self reachabilityWithAddress: &zeroAddress];
}

+ (FMReachability*)reachabilityForLocalWiFi {
	struct sockaddr_in localWifiAddress;
	bzero(&localWifiAddress, sizeof(localWifiAddress));
	localWifiAddress.sin_len = sizeof(localWifiAddress);
	localWifiAddress.sin_family = AF_INET;
	// IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
	localWifiAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
	FMReachability* retVal = [self reachabilityWithAddress:&localWifiAddress];
	if(retVal!= NULL) {
		retVal->localWiFiRef = YES;
	}
	return retVal;
}

#pragma mark Network Flag Handling

- (FMNetworkStatus)localWiFiStatusForFlags:(SCNetworkReachabilityFlags)flags {
	BOOL retVal = NotReachable;
	if((flags & kSCNetworkReachabilityFlagsReachable) && (flags & kSCNetworkReachabilityFlagsIsDirect))
	{
		retVal = ReachableViaWiFi;
	}
	return retVal;
}

- (FMNetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags {
	if((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
		// if target host is not reachable
		return NotReachable;
	}

	BOOL retVal = NotReachable;

	if((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
		// if target host is reachable and no connection is required
		//  then we'll assume (for now) that you're on Wi-Fi
		retVal = ReachableViaWiFi;
	}

	if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
        // ... and the connection is on-demand (or on-traffic) if the
        //     calling application is using the CFSocketStream or higher APIs

        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            // ... and no [user] intervention is needed
            retVal = ReachableViaWiFi;
        }
    }

	if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
		// ... but WWAN connections are OK if the calling application
		//     is using the CFNetwork (CFSocketStream?) APIs.
		retVal = ReachableViaWWAN;
	}
    
	return retVal;
}

- (BOOL)connectionRequired {
	SCNetworkReachabilityFlags flags;
	if(SCNetworkReachabilityGetFlags(reachabilityRef, &flags)) {
		return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
	}
	return NO;
}

- (FMNetworkStatus) currentReachabilityStatus {
	FMNetworkStatus retVal = NotReachable;
	SCNetworkReachabilityFlags flags;

    if(SCNetworkReachabilityGetFlags(reachabilityRef, &flags)) {
		if(localWiFiRef) {
			retVal = [self localWiFiStatusForFlags:flags];
		}
		else {
			retVal = [self networkStatusForFlags:flags];
		}
	}

	return retVal;
}


@end
