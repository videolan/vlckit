<img src="https://www.videolan.org/images/vlckit/logo.svg" alt="VLCKit logo" height="140">

#

**VLCKit** is a generic multimedia library for any audio or video playback needs on macOS, iOS and tvOS.

|              | Platform                                                     | Master                                                       | Cocoapods                                                    |
| ------------ | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| VLCKit       | ![Platform](https://img.shields.io/cocoapods/p/VLCKit.svg?style=flat) | ![CircleCI](https://img.shields.io/circleci/project/github/videolan/vlckit/master.svg) | [![VLCKit is CocoaPods Compatible](https://img.shields.io/cocoapods/v/VLCKit.svg)](https://cocoapods.org/pods/VLCKit) |
| MobileVLCKit | ![Platform](https://img.shields.io/cocoapods/p/MobileVLCKit.svg?style=flat) | ![CircleCI](https://img.shields.io/circleci/project/github/videolan/vlckit/master.svg) | [![MobileVLCKit is CocoaPods Compatible](https://img.shields.io/cocoapods/v/MobileVLCKit.svg)](https://cocoapods.org/pods/MobileVLCKit) |
| TVVLCKit     | ![Platform](https://img.shields.io/cocoapods/p/TVVLCKit.svg?style=flat) | ![CircleCI](https://img.shields.io/circleci/project/github/videolan/vlckit/master.svg) | [![TVVLCKit is CocoaPods Compatible](https://img.shields.io/cocoapods/v/TVVLCKit.svg)](https://cocoapods.org/pods/TVVLCKit) |

## Table of content

- [Features](#features)
- [Use-case](#use-case)
- [Requirements](#requirements)
- [Installation](#installation)
    - [Cocoapods](#cocoapods)
    - [Carthage](#carthage)
- [Build](#build)
    - [Default](#default)
    - [Build with your own VLC repository](#build-with-your-own-vlc-repository)
- [Contribute](#contribute)
    - [Pull Request](#pull-request)
    - [GitLab Issues](#gitlab-issues)
    - [Patches](#patches)
- [FAQ](#faq)
- [Communication](#communication)
    - [Forum](#forum)
    - [Issues](#issues)
    - [IRC](#irc)
- [License](#license)
- [Further reading](#further-reading)

## Features

- Wrapper of **libVLC**, the engine of the popular media player *VLC*.
- Supports playback, active streaming, and media to file conversations on the Mac.
- Open-source software licensed under [LGPLv2.1](http://opensource.org/licenses/LGPL-2.1/) or later, available in source code and binary form from [VideoLAN's website](http://www.videolan.org/).
- Easily integratable via [CocoaPods](http://cocoapods.org/).

## Use-case

When will you need VLCKit?

Frankly, you will need it whenever you need to play media not supported by QuickTime / AVFoundation or if you require more flexibility.

Here are some other common use-cases:

- Playing something else besides H264/AAC files or HLS streams.
- Need subtitles beyond QuickTime’s basic support for Closed Captions.
- Your media source is neither your mobile device nor a basic HTTP server, but a live stream hailing from some weird media server or even a raw DVB signal broadcasted on a local network.
- and more!

## Requirements

- iOS 8.4 + / macOS 10.9+ / tvOS 10.2+
- Xcode 9.0+
- Cocoapods 1.4+
- Python 3.7 (compile time only)

## Installation

### Cocoapods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
gem install cocoapods
```

To integrate the latest VLCKit into your project, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'

target '<macOS Target>' do
    platform :macos, '10.9'
    pod 'VLCKit', '~>3.3.0'
end

target '<iOS Target>' do
    platform :ios, '8.4'
    pod 'MobileVLCKit', '~>3.3.0'
end

target '<tvOS Target>' do
    platform :tvos, '10.2'
    pod 'TVVLCKit', '~>3.3.0'
end
```

Then, run the following command:

```bash
pod install
```
### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a way to add frameworks to your Cocoa application. You can install it with the following command:

```bash
brew install carthage
```

To integrate VLCKit into your project, specify it in your `Cartfile`. The URL depends on your target OS.

iOS:
```
binary "https://code.videolan.org/videolan/VLCKit/raw/master/Packaging/MobileVLCKit.json" ~> 3.3.0
```

macOS:
```
binary "https://code.videolan.org/videolan/VLCKit/raw/master/Packaging/VLCKit.json" ~> 3.3.0
```

tvOS:
```
binary "https://code.videolan.org/videolan/VLCKit/raw/master/Packaging/TVVLCKit.json" ~> 3.3.0
```

Then, run the following command:

```bash
carthage update
```

Note that the following system dependencies are required and need to be linked into the project:

* AudioToolbox.framework
* AVFoundation.framework
* CFNetwork.framework
* CoreFoundation.framework
* CoreGraphics.framework
* CoreMedia.framework
* CoreText.framework
* CoreVideo.framework
* Foundation.framework
* libbz2.tbd
* libiconv.tbd
* OpenGLES.framework
* QuartzCore.framework
* Security.framework
* VideoToolbox.framework

On iOS and tvOS, you also need to link:

* UIKit.framework

## Build

### Default

Make sure that Python 3.7 is installed. Get the package from https://www.python.org - do NOT use homebrew for installation as it will be ignored by VLC's build process.

Run `compileAndBuildVLCKit.sh` with the `-a ${ARCH}` option to specify the target architecture.

More information can be found under `./compileAndBuildVLCKit.sh -h`.

### Build with your own VLC repository

1. Put a VLC repository inside `libvlc/vlc`.

    `mkdir libvlc && cd libvlc && ln -s "PATH_TO_VLC"`

2. Apply VLC patches needed for VLCKit.

    `cd vlc`

    `git am ../libvlc/patches/*`

3. run `compileAndBuildVLCKit.sh` with the `-n` option.

## Contribute

As VLCKit is an open-source project hosted by VideoLAN, we happily welcome all kinds of contributions.

### Pull Request

Pull requests are more than welcome! If you do submit one, please make sure to use a descriptive title and description.

### GitLab Issues

You can look through the currently open [issues on GitLab](https://code.videolan.org/videolan/vlckit/issues/) and choose the one that interests you the most.

### Patches

If you like the more classic apporach, you can submit patches!

For detailed explanation on how to do so, please read our wiki page on [how to send patches](https://wiki.videolan.org/Sending_Patches_VLC/).

## FAQ

> Q. Since this isn't under the MIT license, is there something special I should know?

The [LGPLv2.1](http://opensource.org/licenses/LGPL-2.1/) allows our software to be included in proprietary apps, *as long as you follow the license.* Here are some key points you should be aware of.

- Make sure to publish any potential changes you do to our software
- Make sure that the end-user is aware that VLCKit is embedded within your greater work
- Make sure that the end-user is aware of the gained rights and is granted access to our code as well as to your additions to our work

For further details, please read the license and consult your lawyer with any questions you might have.

## Communication

### Forum

If you ever need help, feel free to reach out. The [forum](http://forum.videolan.org/) is always there for you.

### Issues

Did you find a bug and want to report it to us? You can create an issue on [GitLab](https://code.videolan.org/videolan/vlckit/issues/) or on our [bug tracker](https://trac.videolan.org/vlc/).

### IRC

Do you have a pressing question or just want to talk? Reach out to us via our IRC channel on the [freenode](http://www.freenode.net/) network's **#videolan** channel.

If you don't have an IRC client at hand, use the [freenode webchat](http://webchat.freenode.net/).

## License

VLCKit is under the [LGPLv2.1](http://opensource.org/licenses/LGPL-2.1/) license.

See [COPYING](./COPYING) for more license info.

## Further reading

You can find more documentation on the [VideoLAN wiki](https://wiki.videolan.org/VLCKit/).
