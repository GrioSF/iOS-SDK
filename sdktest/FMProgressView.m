//
//  FMProgressView.m
//  sdktest
//
//  Created by James Anthony on 10/2/12.
//  Copyright (c) 2012 Feed Media, Inc. All rights reserved.
//

#import "FMProgressView.h"
#import <QuartzCore/QuartzCore.h>

@interface FMProgressView (){
    CALayer *progressLayer;
}
@end

@implementation FMProgressView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:.6 green:.6 blue:.6 alpha:1.0];
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue
                         forKey:kCATransactionDisableActions];
        progressLayer = [[CALayer alloc] init];
        progressLayer.backgroundColor = [[UIColor colorWithRed:.05 green:.23 blue:.48 alpha:1.0] CGColor];
        progressLayer.frame = self.bounds;
        [self.layer addSublayer:progressLayer];
        [CATransaction commit];
        self.opaque = YES;
    }
    return self;
}

- (void) layoutSubviews {
    [self setProgress:self.progress];
}

- (void)setProgress:(float)progress withAnimationDuration:(NSTimeInterval)duration {
    progress = MIN(MAX(0,progress),1.0);
    if(isnan(progress)) {
        progress = 0;
    }
    [CATransaction begin];
    if(progress < _progress) {
        [CATransaction setValue:(id)kCFBooleanTrue
                         forKey:kCATransactionDisableActions];
    }
    else if(duration > 0) {
        [CATransaction setValue:@(duration) forKey:kCATransactionAnimationDuration];
    }
    progressLayer.frame = CGRectMake(0,0,progress*self.bounds.size.width,self.bounds.size.height);
    [CATransaction commit];
    _progress = progress;
}

- (void)setProgress:(float)progress {
    [self setProgress:progress withAnimationDuration:0];
}


@end
