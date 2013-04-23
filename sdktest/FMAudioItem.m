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

        // Fail if json doesn't contain a playId, or a contentUrl

        NSString *playId = jsonDictionary[@"id"];
        if(![playId isKindOfClass:[NSString class]] || [playId isEqualToString:@""]) {
            return nil;
        }
        _playId = playId;

        NSDictionary *trackDict = jsonDictionary[@"blip"][@"audio_file"];
        NSString *fileLocation = trackDict[@"url"];
        if([fileLocation isKindOfClass:[NSString class]] && ![fileLocation isEqualToString:@""]) {
            _contentUrl = [NSURL URLWithString:fileLocation];
        }
        if(_contentUrl == nil) {
            return nil;
        }
        //DEBUGGING ONLY:
//        _contentUrl = [NSURL URLWithString:@"http://stor01.fuzz.com/files/8/55/T2PRul-tc.mp3"];

        // Be tolerant if any metadata is missing or empty

        NSString *trackTitle = trackDict[@"track"][@"title"];
        if([trackTitle isKindOfClass:[NSString class]]) {
            _name = trackTitle;
        }

        NSString *artistName = trackDict[@"artist"][@"name"];
        if([artistName isKindOfClass:[NSString class]]) {
            _artist = artistName;
        }

        NSString *albumTitle = trackDict[@"release"][@"title"];
        if([albumTitle isKindOfClass:[NSString class]]) {
            _album = albumTitle;
        }

        NSString *codec = trackDict[@"codec"];
        if([codec isKindOfClass:[NSString class]]) {
            _codec = codec;
        }

        id duration = trackDict[@"duration_in_seconds"];
        if([duration respondsToSelector:@selector(doubleValue)]) {
            _duration = [duration doubleValue];
        }

        id bitrate = trackDict[@"bitrate"];
        if([bitrate respondsToSelector:@selector(doubleValue)]) {
            _bitrate = [bitrate doubleValue];
        }
    }
    return self;
}

- (NSString *)identifier {
    return self.playId;
}

- (BOOL)isEqual:(id)object {
    if(![object isKindOfClass:[self class]]) return NO;
    return ([[self identifier] isEqual:[(FMAudioItem *)object identifier]]);
}

- (NSUInteger)hash {
    return [[self identifier] hash];
}

@end
