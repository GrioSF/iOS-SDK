Feed Media SDK for iOS Quickstart Guide

Introduction
============

The Feed Media SDK for iOS allows you to play DMCA compliant radio within your iOS apps. You can read more about the Feed Media API at [http://feed.fm/][1]. The primary object used to communicate with the Feed API is the `FMSession` singleton. You can either use it directly to request track information (if using your own audio player), or use the `FMAudioPlayer` class to let the SDK handle playback. 

This quickstart guide assumes you will be using a single placement and the `FMAudioPlayer` class, which uses `AVFoundation` for audio playback: please see the full documentation if you're using multiple placements or you need to write your own playback engine.

Before you begin, you should have an account at feed.fm and set up at least one *placement* and *station*. If you have not already done so, please go to [http://feed.fm/][2]. 

Definitions
===========

*Placement*: A placement is a way to identify a location to play music in. It consists of one or more stations to pull music from, and budget rules to limit how much music to serve (on a per user or per placement basis). You may have one or more placements in your app. You can manage your placements at [http://feed.fm/][2].

*Station*: A station is a collection of music that you select using the dashboard at [http://feed.fm/][2]. One station can be assigned to multiple placements.

*Client Token* and *Client Secret*: When you create an account at [http://feed.fm/][3], you are issued a unique client token and secret. These keys are used to identify your app to the Feed Media API.

Adding Files
============

1. Add the SDK to your project: File --&gt; Add Files to "&lt;Your Project&gt;"...
    1. Chose the "Feed SDK" folder in the dialog
    2. For "Destination", check "Copy items into destination group's folder (if needed)"
    3. For "Folders", select "Create groups for any added folders"
    4. For "Add to targets", check all targets where you'll be using the SDK
2. Link required libraries
    1. Select your project in the Project Navigator
    2. Select your target
    3. Select the "Build Phases" tab
    4. Expand "Link Binary With Libraries"
    5. Click the "+" to add `CoreMedia.framework` and `AVFoundation.framework`

Initializing the SDK
====================

1) In your Application Delegate, import FMSession

    #import "FMSession.h"

2) Set your client token and secret, placementId, and optionally set the log level:

    -(BOOL)application:(UIApplication *)application 
                didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

        FMLogSetLevel(FMLogLevelDebug);
        [FMSession setClientToken:@"Your Client Token"
                           secret:@"Your Client Secret"];
        [[FMSession sharedSession] setPlacement:@"Your Placement ID"];

        // Your app specific setup...
        return YES;
    }

Playing Music with FMAudioPlayer
================================

1) In your View Controller, import FMAudioPlayer: 

    #import "FMAudioPlayer.h"

2) Initialize an FMAudioPlayer and store it in a property:

    self.player = [[FMAudioPlayer alloc] initWithSession:[FMSession sharedSession]];

3) Register for notifications to update your UI to display song metadata

    - (void)viewDidLoad {
        [super viewDidLoad];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSongMetadata:)name:FMSessionCurrentItemChangedNotification object:[[FMSession sharedSession]]];
        // Your view controller's internal setup...
    }

    -(void)updateSongMetadata:(NSNotification)notification {
        // use the properties of [FMSession sharedSession].currentItem like `name`, `artist`, `album`, etc...
    }

    // Remember to remove yourself from notifications on dealloc
    - (void)dealloc {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }

4) Optionally request available stations:

    [[FMSession sharedSession] requestStationsForPlacement:nil
                                               withSuccess:^(NSArray *stations) 
    {
        //Present the user with the list of stations to choose from
        //`stations` is a list of FMStation objects, which have a `name` NSString property for display
    }
                                                   failure:^(NSError *error) 
    {
        NSLog(@"Failed to receive stations: %@", error);
    }];

5) Optionally set a specific station to play (if this step is omitted, the player will use the active placement's default station):

    FMStation *station = stations[i];   //assume user selected the ith station from a -requestStations call
    [[FMSession sharedSession] setStation:station];

6) Begin playback:

    [self.player play];

Managing your AudioSession
==========================

The Feed Media SDK does *not* modify your application's audio session. Please see Apple's [documentation on Audio Session Programming][4]. In particular, note that the default audio session category respects the silent switch, so you should make sure to either pause audio while the silent switch is active or choose a different category for your app.


[1]: http://feed.fm/documentation
[2]: http://feed.fm/dashboard
[3]: http://feed.fm/
[4]: http://developer.apple.com/library/ios/#documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html