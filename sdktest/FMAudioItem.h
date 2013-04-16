//
//  FMAudioItem.h
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FMAudioItem : NSObject

@property (readonly) NSString *playId;
@property (readonly) NSString *name;
@property (readonly) NSString *artist;
@property (readonly) NSString *album;

@property (readonly) NSTimeInterval duration;
@property (readonly) NSURL *contentUrl;
@property (readonly) NSString *codec;
@property (readonly) double bitrate;        //in kbps, will be average if song is encoded with vbr

- (id)initWithJSON:(id)jsonDictionary;

@end