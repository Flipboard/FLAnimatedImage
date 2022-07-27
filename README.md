# [FLAnimatedImage](https://github.com/Flipboard/FLAnimatedImage) &middot; [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Flipboard/FLAnimatedImage/blob/master/LICENSE) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/Flipboard/FLAnimatedImage/pulls)

FLAnimatedImage is a performant animated GIF engine for iOS:

- Plays multiple GIFs simultaneously with a playback speed comparable to desktop browsers
- Honors variable frame delays
- Behaves gracefully under memory pressure
- Eliminates delays or blocking during the first playback loop
- Interprets the frame delays of fast GIFs the same way modern browsers do

It's a well-tested [component that powers all GIFs in Flipboard](http://engineering.flipboard.com/2014/05/animated-gif). To understand its behavior it comes with an interactive demo:

![Flipboard playing multiple GIFs](https://github.com/Flipboard/FLAnimatedImage/raw/master/images/flanimatedimage-demo-player.gif)

## Who is this for?

- Apps that don't support animated GIFs yet
- Apps that already support animated GIFs but want a higher performance solution
- People who want to tinker with the code ([the corresponding blog post](http://engineering.flipboard.com/2014/05/animated-gif/) is a great place to start; also see the *To Do* section below)

## Installation & Usage

FLAnimatedImage is a well-encapsulated drop-in component. Simply replace your `UIImageView` instances with instances of `FLAnimatedImageView` to get animated GIF support. There is no central cache or state to manage.

If using CocoaPods, the quickest way to try it out is to type this on the command line:

```shell
$ pod try FLAnimatedImage
```

To add it to your app, copy the two classes `FLAnimatedImage.h/.m` and `FLAnimatedImageView.h/.m` into your Xcode project or add via [CocoaPods](http://cocoapods.org) by adding this to your Podfile:

```ruby
pod 'FLAnimatedImage', '~> 1.0'
```

If using [Carthage](https://github.com/Carthage/Carthage), add the following line into your `Cartfile`

```
github "Flipboard/FLAnimatedImage"
```

If using [Swift Package Manager](https://github.com/apple/swift-package-manager), add the following to your `Package.swift` or add via XCode:

```swift
dependencies: [
    .package(url: "https://github.com/Flipboard/FLAnimatedImage.git", .upToNextMajor(from: "1.0.16"))
],
targets: [
    .target(name: "TestProject", dependencies: ["FLAnimatedImage""])
]
```

In your code, `#import "FLAnimatedImage.h"`, create an image from an animated GIF, and setup the image view to display it:

```objective-c
FLAnimatedImage *image = [FLAnimatedImage animatedImageWithGIFData:[NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://upload.wikimedia.org/wikipedia/commons/2/2c/Rotating_earth_%28large%29.gif"]]];
FLAnimatedImageView *imageView = [[FLAnimatedImageView alloc] init];
imageView.animatedImage = image;
imageView.frame = CGRectMake(0.0, 0.0, 100.0, 100.0);
[self.view addSubview:imageView];
```

It's flexible to integrate in your custom image loading stack and backwards compatible to iOS 9.

It uses ARC and the Apple frameworks `QuartzCore`, `ImageIO`, `MobileCoreServices`, and `CoreGraphics`.

It is capable of fine-grained logging. A block can be set on `FLAnimatedImage` that's invoked when logging occurs with various log levels via the `+setLogBlock:logLevel:` method. For example:

```objective-c
// Set up FLAnimatedImage logging.
[FLAnimatedImage setLogBlock:^(NSString *logString, FLLogLevel logLevel) {
    // Using NSLog
    NSLog(@"%@", logString);

    // ...or CocoaLumberjackLogger only logging warnings and errors
    if (logLevel == FLLogLevelError) {
        DDLogError(@"%@", logString);
    } else if (logLevel == FLLogLevelWarn) {
        DDLogWarn(@"%@", logString);
    }
} logLevel:FLLogLevelWarn];
```

Since FLAnimatedImage is licensed under MIT, it's compatible with the terms of using it for any app on the App Store.

## Release process
1. Bump version in `FLAnimatedImage.podspec`, update CHANGES, and commit.
2. Tag commit with `> git tag -a <VERSION> -m "<VERSION>"` and `> git push --tags`.
3. [Submit Podspec to Trunk with](https://guides.cocoapods.org/making/specs-and-specs-repo.html#how-do-i-update-an-existing-pod) `> pod trunk push FLAnimatedImage.podspec` ([ensure you're auth'ed](https://guides.cocoapods.org/making/getting-setup-with-trunk.html#getting-started)).
## To Do
- Support other animated image formats such as APNG or WebP (WebP support implemented [here](https://github.com/Flipboard/FLAnimatedImage/pull/86))
- Integration into network libraries and image caches
- Investigate whether `FLAnimatedImage` should become a `UIImage` subclass
- Smarter buffering
- Bring demo app to iPhone

This code has successfully shipped to many people as is, but please do come with your questions, issues and pull requests!

## Select apps using FLAnimatedImage
(alphabetically)

- [Close-up](http://closeu.pe)
- [Design Shots](https://itunes.apple.com/app/id792517951)
- [Dropbox](https://www.dropbox.com)
- [Dumpert](http://dumpert.nl)
- [Ello](https://ello.co/)
- [Facebook](https://facebook.com)
- [Flipboard](https://flipboard.com)
- [getGIF](https://itunes.apple.com/app/id964784701)
- [Gifalicious](https://itunes.apple.com/us/app/gifalicious-see-your-gifs/id965346708?mt=8)
- [HashPhotos](https://itunes.apple.com/app/id685784609)
- [Instagram](https://www.instagram.com/)
- [LiveBooth](http://www.liveboothapp.com)
- [lWlVl Festival](http://lwlvl.com)
- [Medium](https://medium.com)
- [Pinterest](https://pinterest.com)
- [Slack](https://slack.com/)
- [Telegram](https://telegram.org/)
- [Zip Code Finder](https://itunes.apple.com/app/id893031254)

If you're using FLAnimatedImage in your app, please open a PR to add it to this list!
