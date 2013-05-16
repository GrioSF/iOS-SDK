//
//  FMMetadataView.m
//  sdktest
//
//  Created by James Anthony on 4/23/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMMetadataView.h"
#import "FMAudioPlayer.h"

@interface FMMetadataView () {
    UILabel *_metadataLabel;
}
@end

@implementation FMMetadataView

- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if(self = [super initWithCoder:aDecoder]) {
        [self setup];
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    _metadataLabel.backgroundColor = self.backgroundColor;
}

- (void)setup {
    _metadataLabel = [[UILabel alloc] init];
    _metadataLabel.frame = self.bounds;
    _metadataLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _metadataLabel.backgroundColor = self.backgroundColor;
    _metadataLabel.font = [UIFont systemFontOfSize:12.0];
    [self addSubview:_metadataLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemUpdated:) name:FMAudioPlayerCurrentItemDidChangeNotification object:[FMAudioPlayer sharedPlayer]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)itemUpdated:(NSNotification *)notification {
    FMAudioItem *currentItem = [FMAudioPlayer sharedPlayer].currentItem;
    if(currentItem != nil) {
        _metadataLabel.text = [NSString stringWithFormat:@"%@ – %@", currentItem.artist, currentItem.name];
    }
    else {
        _metadataLabel.text = @"";
    }
}

@end
