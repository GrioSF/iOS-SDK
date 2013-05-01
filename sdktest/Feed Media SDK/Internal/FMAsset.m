//
//  FMAsset.m
//  sdktest
//
//  Created by James Anthony on 4/26/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMAsset.h"
#import "FMLog.h"
#import "FMError.h"

#define kTracksKey @"tracks"
#define kPlayableKey @"playable"

@interface FMAsset () {
    BOOL _loadingInProgress;
    BOOL _isCanceled;
    AVAsset *_asset;
}
@property (nonatomic, copy) void (^successBlock)(FMAsset *asset, AVPlayerItem *playerItem);
@property (nonatomic, copy) void (^failureBlock)(FMAsset *asset, NSError *error);
@end

@implementation FMAsset

+ (FMAsset *)assetWithAudioItem:(FMAudioItem *)item {
    return [[FMAsset alloc] initWithAudioItem:item];
}

- (void) dealloc {
    [self cancel];
}

- (id)init {
    return [self initWithAudioItem:nil];
}

- (id)initWithAudioItem:(FMAudioItem *)item {
    if(self = [super init]) {
        _audioItem = item;
    }
    return self;
}

- (void)setCompletionBlockWithSuccess:(void (^)(FMAsset *asset, AVPlayerItem *playerItem))success
                              failure:(void (^)(FMAsset *asset, NSError *error))failure {
    if(_isCanceled) return;
    
    if(self.loadError) {
        dispatch_async(dispatch_get_main_queue(), ^{failure(self, self.loadError);});
    }
    else if(self.playerItem) {
        dispatch_async(dispatch_get_main_queue(), ^{success(self, self.playerItem);});
    }
    else {
        self.successBlock = success;
        self.failureBlock = failure;
    }
}

- (void)cancel {
    FMLogDebug(@"Asset Load Canceled");
    self.failureBlock = nil;
    self.successBlock = nil;
    [_asset cancelLoading];
    _asset = nil;
    _playerItem = nil;
    _isCanceled = YES;
}

- (void)completeWithItem:(AVPlayerItem *)item {
    _playerItem = item;
    _loadingInProgress = NO;
    if(self.successBlock && !_isCanceled) {
        FMLogDebug(@"Dispatching completion block");
        dispatch_async(dispatch_get_main_queue(), ^{self.successBlock(self, self.playerItem);});
    }
}

- (void)failWithError:(NSError *)error {
    _loadError = error;
    _loadingInProgress = NO;
    _asset = nil;
    _playerItem = nil;
    if(self.failureBlock && !_isCanceled) {
        dispatch_async(dispatch_get_main_queue(), ^{self.failureBlock(self, self.loadError);});
    }
}

- (void)loadPlayerItem {
    if(self.audioItem == nil) return;
    if(_loadingInProgress) return;
    if(self.playerItem) return;

    _loadingInProgress = YES;
    _isCanceled = NO;

    NSURL *itemUrl = self.audioItem.contentUrl;
    if(itemUrl == nil) {
        NSError *error = [NSError errorWithDomain:FMAPIErrorDomain
                                             code:FMErrorCodeUnexpectedReturnType
                                         userInfo:@{
                       NSLocalizedDescriptionKey : @"Audio Item Missing Content Url",
                NSLocalizedFailureReasonErrorKey : [NSString stringWithFormat:@"Tried to load %@ but contentUrl property was nil", self.audioItem]}];
        [self failWithError:error];
        return;
    }
    FMLogDebug(@"Requesting asset for %@",itemUrl);
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:itemUrl options:nil];
    _asset = asset;
    NSArray *requestedKeys = [NSArray arrayWithObjects:kTracksKey, kPlayableKey, nil];
    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
     ^{
         dispatch_async( dispatch_get_main_queue(),
                        ^{
                            /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
                            [self prepareToPlayAsset:asset withKeys:requestedKeys];
                        });
     }];
}

- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys {
    FMLogDebug(@"Prepare to play asset");

    if(_isCanceled) {
        return;
    }

    /* Make sure that the value of each key has loaded successfully. */
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
			[self failWithError:error];
			return;
		}
	}

    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable)
    {
		NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"FMAssetLoadingErrorDomain"
                                                                code:0
                                                            userInfo:@{
                                          NSLocalizedDescriptionKey : @"Item could not be played",
                                   NSLocalizedFailureReasonErrorKey : @"The assets tracks were loaded, but could not be made playable."}];

        /* Display the error to the user. */
        [self failWithError:assetCannotBePlayedError];

        return;
    }

    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    [self completeWithItem:[AVPlayerItem playerItemWithAsset:asset]];
}

@end

#undef kTracksKey
#undef kPlayableKey
