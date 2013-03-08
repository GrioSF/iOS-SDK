//
//  FMMediaItem.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FMMediaItem : NSObject

@property (readonly) NSString *playId;
@property (readonly) NSString *name;
@property (readonly) NSString *artist;
@property (readonly) NSString *album;
@property (readonly) NSURL *imageUrl;       //album art
@property (readonly) NSURL *storeUrl;       //itms link

@property (readonly) NSTimeInterval duration;
@property (readonly) NSURL *contentUrl;
@property (readonly) NSString *codec;
@property (readonly) double bitrate;

@end