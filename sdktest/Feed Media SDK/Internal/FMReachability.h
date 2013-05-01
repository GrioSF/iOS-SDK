//
//  FMReachability.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//  Contains code copyright (c) 2011 Apple Inc. from the sample code Reachability
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

typedef enum : NSUInteger {
	NotReachable = 0,
	ReachableViaWiFi,
	ReachableViaWWAN
} FMNetworkStatus;

extern NSString *const FMReachabilityChangedNotification;

@interface FMReachability : NSObject

//reachabilityWithHostName- Use to check the reachability of a particular host name.
+ (FMReachability *)reachabilityWithHostName: (NSString*) hostName;

//reachabilityWithAddress- Use to check the reachability of a particular IP address.
+ (FMReachability *)reachabilityWithAddress: (const struct sockaddr_in*) hostAddress;

//reachabilityForInternetConnection- checks whether the default route is available.
//  Should be used by applications that do not connect to a particular host
+ (FMReachability *)reachabilityForInternetConnection;

//reachabilityForLocalWiFi- checks whether a local wifi connection is available.
+ (FMReachability *)reachabilityForLocalWiFi;

//Start listening for reachability notifications on the current run loop
- (BOOL)startNotifier;
- (void)stopNotifier;

- (FMNetworkStatus)currentReachabilityStatus;

//WWAN may be available, but not active until a connection has been established.
//WiFi may require a connection for VPN on Demand.
- (BOOL)connectionRequired;

@end
