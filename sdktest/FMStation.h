//
//  FMStation.h
//  sdktest
//
//  Created by James Anthony on 3/11/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FMStation : NSObject <NSCopying>

@property (readonly) NSString *name;
@property (readonly) NSString *identifier;

- (id)initWithJSON:(id)jsonDictionary;

@end
