Pod::Spec.new do |s|
  s.name         = "iOS-SDK"
  s.version      = "1.0"
  s.summary      = "Feed Media SDK"
  s.description  = <<-DESC
                    Feed Media SDK for iOS Quickstart Guide

                    Introduction
                    ============

                    The Feed Media SDK for iOS allows you to play DMCA compliant radio within your iOS apps. You can read more about the Feed Media API at [http://feed.fm/][1]. The primary object you will use to access the Feed Media API is the `FMAudioPlayer` singleton, which uses `AVFoundation` for audio playback.

                    This quickstart guide assumes you will be using a single placement and the static library distribution of the Feed Media SDK, but the full source is available on Github at [https://github.com/fuzz-radio/iOS-SDK][2]. 

                    Before you begin, you should have an account at feed.fm and set up at least one *placement* and *station*. If you have not already done so, please go to [http://feed.fm/][3]. 


                    Resources
                    =========

                    For more information, please contact `support@fuzz.com` or check out our Github repo at [https://github.com/fuzz-radio/iOS-SDK][2].

                    [1]: http://feed.fm/documentation
                    [2]: https://github.com/fuzz-radio/iOS-SDK
                    [3]: http://feed.fm/dashboard
                    [4]: http://feed.fm/
                   DESC

  s.homepage     = "https://github.com/fuzz-radio/iOS-SDK"
  s.author       = { "FUZZ ftw!" => "eric@fuzz.com" }
  s.source       = { :git => "https://github.com/GrioSF/iOS-SDK.git" }
  s.source_files = "sdktest/Feed Media SDK/Internal", "sdktest/Feed Media SDK/Internal/**/*.{h,m}", "sdktest/Feed Media SDK", "sdktest/Feed Media SDK/**/*.{h,m}"
  s.public_header_files = "sdktest/Feed Media SDK/**/*.h"
  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.framework    = "CoreMedia", "AVFoundation", "SystemConfiguration"
end
