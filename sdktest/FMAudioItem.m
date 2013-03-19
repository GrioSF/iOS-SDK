//
//  FMAudioItem.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMAudioItem.h"

@implementation FMAudioItem

- (id)initWithJSON:(id)jsonDictionary {
    if(self = [super init]) {
        if(![jsonDictionary isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        // Fail if json doesn't contain a play object, a playId, or a contentUrl

        NSDictionary *playDict = jsonDictionary[@"play"];
        if(![playDict isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        NSString *playId = playDict[@"id"];
        if(![playId isKindOfClass:[NSString class]] || [playId isEqualToString:@""]) {
            return nil;
        }
        _playId = playId;

        NSString *fileLocation = playDict[@"blip"][@"audio_file"][@"url"];
        if([fileLocation isKindOfClass:[NSString class]] && ![fileLocation isEqualToString:@""]) {
            _contentUrl = [NSURL URLWithString:fileLocation];
        }
        if(_contentUrl == nil) {
            return nil;
        }

        // Be tolerant if any metadata is missing or empty

        NSString *trackTitle = playDict[@"blip"][@"audio_file"][@"track"][@"title"];
        if([trackTitle isKindOfClass:[NSString class]]) {
            _name = trackTitle;
        }

        NSString *artistName = playDict[@"blip"][@"audio_file"][@"artist"][@"name"];
        if([artistName isKindOfClass:[NSString class]]) {
            _artist = artistName;
        }

        NSString *albumTitle = playDict[@"blip"][@"audio_file"][@"release"][@"title"];
        if([albumTitle isKindOfClass:[NSString class]]) {
            _album = albumTitle;
        }

        NSString *codec = playDict[@"blip"][@"audio_file"][@"codec"];
        if([codec isKindOfClass:[NSString class]]) {
            _codec = codec;
        }

        id duration = playDict[@"blip"][@"audio_file"][@"duration_in_seconds"];
        if([duration respondsToSelector:@selector(doubleValue)]) {
            _duration = [duration doubleValue];
        }

        id bitrate = playDict[@"blip"][@"audio_file"][@"kbitrate"];
        if([bitrate respondsToSelector:@selector(doubleValue)]) {
            _bitrate = [bitrate doubleValue];
        }
    }
    return self;
}

@end
