# VLCKit

**VLCKit** is a generic multimedia library for any audio or video playback needs on macOS, iOS and tvOS.

It is based on **libVLC**, the engine of the popular media player *VLC*.

It supports playback, but also  active streaming and media to file conversations on the Mac.

It is open-source software licensed under LGPLv2.1 or later, available in source code and binary form from the [VideoLAN website].

You can also integrate VLCKit and its mobile version MobileVLCKit easily via [CocoaPods].


## Use-case

When do you need VLCKit? Frankly always when you need to play media not supported by QuickTime / AVFoundation or if you require more flexibility. You want to play something else besides H264/AAC files or HLS streams? You need subtitles beyond QuickTime’s basic support for Closed Captions? Your media source is not your mobile device and not a basic HTTP server either, but perhaps a live stream hailing from some weird media server or even a raw DVB signal broadcasted on a local network? Then, VLCKit is for you.

But this is open-source software right? What does this mean for me and the end-user? And wasn’t MobileVLC removed from the App Store in 2011 for some crazy licensing reason?

First of all, open-source means for you, that you get access to the whole stack. There is no blackbox, all the sources are there at your fingertips. No reverse-engineering needed, no private APIs.

Then again, this must not be the case for your software. The [LGPLv2.1] allows our software to be included in proprietary apps, as long as you follow the license. As a start, make sure to publish any potential changes you do to our software, make sure that the end-user is aware that VLCKit is embedded within your greater work and that s/he is aware of the gained rights. S/he is granted access to our code as well as to your additions to our work. For further details, please read the license and consult your lawyer with any questions you might have.

## Contribute!

As VLCKit is an open-source project hosted by VideoLAN, we happily welcome all kinds of contributions to it.

For detailed information on the development process, please read below and our wiki page on [how to send patches].

### Build

Run `buildMobileVLCKit.sh` with the `-a ${ARCH}` option

### Build with your own VLC repository
1. Put a vlc repository inside libvlc/vlc
     
    `mkdir libvlc && cd libvlc && ln -s ${MYVLCGIT}`

2. Apply VLC patches needed for VLCKit
     
    `cd vlc`
    
    `git am ../../Resources/MobileVLCKit/patches/* `

3. run `buildMobileVLCKit.sh` with the `-n` and the `-a ${ARCH}` option 

## Get in touch!

We happily provide guidance on VLCKit. The [web forum] is always there for you.

If you prefer live interaction, reach out to us via our IRC channel on the [freenode] Network (irc.freenode.org, #videolan). Use the [Freenode Web] interface, if you don't have an IRC client at hand.

## Further reading

You can find more documentation on the [VideoLAN wiki].

   [VideoLAN website]: <http://www.videolan.org/>
   [CocoaPods]: <http://cocoapods.org/>
   [VideoLAN wiki]: <https://wiki.videolan.org/VLCKit/>
   [LGPLv2.1]: <http://opensource.org/licenses/LGPL-2.1>
   [how to send patches]: <https://wiki.videolan.org/Sending_Patches_VLC/>
   [web forum]: <http://forum.videolan.org>
   [freenode]: <http://www.freenode.net/>
   [Freenode Web]: <http://webchat.freenode.net/>
