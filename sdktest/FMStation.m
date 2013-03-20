//
//  FMStation.m
//  sdktest
//
//  Created by James Anthony on 3/11/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMStation.h"

@implementation FMStation

- (id)initWithJSON:(id)jsonDictionary {
    if(self = [super init]) {
        if(![jsonDictionary isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        // Tolerate number or string ids, but fail if can't recover a meaningful version of either
        id identifier = jsonDictionary[@"id"];
        if([identifier isKindOfClass:[NSNumber class]] && ![identifier integerValue] == 0) {
            _identifier = [NSString stringWithFormat:@"%ld",(long)[identifier integerValue]];
        }
        else if([identifier isKindOfClass:[NSString class]] && ![identifier isEqualToString:@""]) {
            _identifier = [identifier copy];
        }
        else {
            return nil;
        }

        id name = jsonDictionary[@"name"];
        if([name isKindOfClass:[NSString class]]) {
            _name = [name copy];
        }
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if(![object isKindOfClass:[self class]]) return NO;
    return ([[self identifier] isEqual:[(FMStation *)object identifier]]);
}

- (NSUInteger)hash {
    return [[self identifier] hash];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;    //immutable, doesn't matter
}

@end
