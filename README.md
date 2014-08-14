FLAnimatedImage is a performant animated GIF engine for iOS:

- Plays multiple GIFs simultaneously with a playback speed comparable to desktop browsers
- Honors variable frame delays
- Behaves gracefully under memory pressure
- Eliminates delays or blocking during the first playback loop
- Interprets the frame delays of fast GIFs the same way modern browsers do

It's a well-tested [component that powers all GIFs in Flipboard](http://engineering.flipboard.com/2014/05/animated-gif/). To understand its behavior it comes with an interactive demo:

![Flipboard playing multiple GIFs](https://github.com/Flipboard/FLAnimatedImage/raw/master/images/flanimatedimage-demo-player.gif)

## Who is this for?

- Apps that don't support animated GIFs yet
- Apps that already support animated GIFs but want a higher performance solution
- People who want to tinker with the code ([the corresponding blog post](http://engineering.flipboard.com/2014/05/animated-gif/) is a great place to start; also see the "To Do" section below)

## Installation & Usage

FLAnimatedImage is a well encapsulated drop-in component. Simply replace your `UIImageView` instances with instances of `FLAnimatedImageView` to get animated GIF support. There is no central cache or state to manage.

If using CocoaPods, the quickest way to try it out is to type this on the command line:

```shell
$ pod try FLAnimatedImage
```

To add it to your app, copy the two classes `FLAnimatedImage.h/.m` and `FLAnimatedImageView.h/.m` into your Xcode project or add via [CocoaPods](http://cocoapods.org) by adding this to your Podfile:

```ruby
pod 'FLAnimatedImage', '~> 1.0'
```

In your code, `#import "FLAnimatedImage.h"` and `#import "FLAnimatedImageView.h"` and then create an image from an animated GIF and setup the image view to display it:

```objective-c
FLAnimatedImage *image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:[NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://raphaelschaad.com/static/nyan.gif"]]];
FLAnimatedImageView *imageView = [[FLAnimatedImageView alloc] init];
imageView.animatedImage = image;
imageView.frame = CGRectMake(0.0, 0.0, 100.0, 100.0);
[self.view addSubview:imageView];
```

It's flexible to integrate in your custom image loading stack and backwards compatible to iOS 5.

It uses ARC and the Apple frameworks `QuartzCore`, `ImageIO`, `MobileCoreServices`, and `CoreGraphics`.

Since FLAnimatedImage is licensed under MIT it's compatible with the terms of using it for any app on the App Store.

## To Do
- Support other animated image formats such as APNG or WebP
- Integration into network libraries and image caches
- Investigate whether `FLAnimatedImage` should become a `UIImage` subclass
- `UIScrollView` support
- Smarter buffering
- Bring demo app to iOS 5 and iPhone

This has shipped to many people and since mid 2013 we made many tweaks. But it's a version 1.0, so please come with your questions, issues and pull requests.

Feel free to reach out to [@RaphaelSchaad](https://twitter.com/raphaelschaad) for further help.
