Feed Media SDK for iOS Quickstart Guide

Introduction
============

The Feed Media SDK for iOS allows you to play DMCA compliant radio within your iOS apps. You can read more about the Feed Media API at [http://feed.fm/][1]. The primary object you will use to access the Feed Media API is the `FMAudioPlayer` singleton, which uses `AVFoundation` for audio playback.

This quickstart guide assumes you will be using a single placement and the static library distribution of the Feed Media SDK, but the full source is available on Github at [https://github.com/fuzz-radio/iOS-SDK][2]. 

Before you begin, you should have an account at feed.fm and set up at least one *placement* and *station*. If you have not already done so, please go to [http://feed.fm/][3]. 

Definitions
===========

*Placement*: A placement is a way to identify a location to play music in. It consists of one or more stations to pull music from, and budget rules to limit how much music to serve (on a per user or per placement basis). You may have one or more placements in your app. You can manage your placements at [http://feed.fm/][3].

*Station*: A station is a collection of music that you select using the dashboard at [http://feed.fm/][3]. One station can be assigned to multiple placements.

*Client Token* and *Client Secret*: When you create an account at [http://feed.fm/][4], you are issued a unique client token and secret. These keys are used to identify your app to the Feed Media API.

Adding Files
============

1. Add the SDK to your project: File --&gt; Add Files to "&lt;Your Project&gt;"...
    1. Chose the "Feed Media SDK" folder in the dialog
    2. For "Destination", check "Copy items into destination group's folder (if needed)"
    3. For "Folders", select "Create groups for any added folders"
    4. For "Add to targets", check all targets where you'll be using the SDK
2. Link required libraries
    1. Select your project in the Project Navigator
    2. Select your target
    3. Select the "Build Phases" tab
    4. Expand "Link Binary With Libraries"
    5. Click the "+" to add `CoreMedia.framework`, `AVFoundation.framework`, and `SystemConfiguration.framework`

Initializing the SDK
====================

1) In your Application Delegate's implementation (`.m` file), add FMAudioPlayer to the list of `#import`ed files

    #import "MyAppDelegate.h"
    //...//
    #import "FMAudioPlayer.h"

2) Set your client token and secret, placementId, and optionally set the log level:

    -(BOOL)application:(UIApplication *)application 
                didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

        FMLogSetLevel(FMLogLevelDebug);
        [FMAudioPlayer setClientToken:@"Your Client Token"
                               secret:@"Your Client Secret"];
        [[FMAudioPlayer sharedPlayer] setPlacement:@"Your Placement ID"];

        // Your app specific setup...
        return YES;
    }

Playing Music with FMAudioPlayer
================================

1) In your View Controller's implementation (`.m` file), add FMAudioPlayer to the list of `#import`ed files: 

    #import "MyViewController.h"
    //...//
    #import "FMAudioPlayer.h"

2) Register for notifications to update your UI to display song metadata

    - (void)viewDidLoad {
        [super viewDidLoad];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSongMetadata:) name:FMAudioPlayerCurrentItemDidChangeNotification object:[FMAudioPlayer sharedPlayer]];
        // Your view controller's internal setup...
    }

    -(void)updateSongMetadata:(NSNotification)notification {
        // Use the properties of [FMAudioPlayer sharedPlayer].currentItem like `name`, `artist`, `album`, etc...
        // You can find the available properties in "FMAudioItem.h"
    }

    // Remember to remove yourself from notifications on dealloc
    - (void)dealloc {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }

3) Optionally request available stations:

    [[FMAudioPlayer sharedPlayer] requestStationsForPlacement:[FMAudioPlayer sharedPlayer].activePlacementId
                                                  withSuccess:^(NSArray *stations) 
    {
        //Present the user with the list of stations to choose from
        //`stations` is a list of FMStation objects, which have a `name` NSString property for display
    }
                                                      failure:^(NSError *error) 
    {
        NSLog(@"Failed to receive stations: %@", error);
    }];

4) Optionally set a specific station to play (if this step is omitted, the player will use the active placement's default station):

    FMStation *station = stations[i];   //assume user selected the ith station from a -requestStations call
    [[FMAudioPlayer sharedPlayer] setStation:station];

5) Begin playback:

    [[FMAudioPlayer sharedPlayer] play];

Resources
=========

For more information, please contact `support@fuzz.com` or check out our Github repo at [https://github.com/fuzz-radio/iOS-SDK][2].


[1]: http://feed.fm/documentation
[2]: https://github.com/fuzz-radio/iOS-SDK
[3]: http://feed.fm/dashboard
[4]: http://feed.fm/
