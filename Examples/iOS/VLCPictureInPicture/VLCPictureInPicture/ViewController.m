/*****************************************************************************
 * ViewController.m :
 *****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * Authors: Maxime Chapelet <umxprime at videolabs dot io>
 *
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "ViewController.h"
#import <VLCKit/VLCKit.h>

@interface ViewController () 
    <VLCDrawable,
     VLCPictureInPictureDrawable, 
     VLCLogging,
     VLCPictureInPictureMediaControlling,
     VLCMediaPlayerDelegate>

@property (weak, nonatomic) IBOutlet UIView *movieView;
@property (weak, atomic) id<VLCPictureInPictureWindowControlling> pipController;
@end

@implementation ViewController
{
    VLCMediaPlayer *_mediaPlayer;
    VLCLibrary *_vlc;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _vlc = [[VLCLibrary alloc] initWithOptions:@[@"-vvvv"]];

    _vlc.loggers = @[self];

    _mediaPlayer = [[VLCMediaPlayer alloc] initWithLibrary:_vlc];
    _mediaPlayer.delegate = self;
    _mediaPlayer.drawable = self;
    _mediaPlayer.minimalTimePeriod = 10000;

    NSURL *mediaURL;
    NSString *mediaPath;
    mediaPath = @"http://streams.videolan.org/streams/mp4/Mr_MrsSmith-h264_aac.mp4";
    mediaURL = [NSURL URLWithString:mediaPath];
    _mediaPlayer.media = [VLCMedia mediaWithURL:mediaURL];
}
#pragma mark - Actions

- (IBAction)pipButtonTouched:(id)sender {
    [self.pipController startPictureInPicture];
}

- (IBAction)playButtonTouched:(id)sender {
    switch (_mediaPlayer.state) {
        case VLCMediaPlayerStatePaused:
        case VLCMediaPlayerStateStopped:
        case VLCMediaPlayerStateStopping:
        case VLCMediaPlayerStateError:
        {
            [_mediaPlayer play];
            break;
        }
        default:
            [_mediaPlayer pause];
    }
}

#pragma mark - VLCPictureInPictureDrawable

- (id<VLCPictureInPictureMediaControlling>)mediaController {
    return self;
}

- (void (^)(id<VLCPictureInPictureWindowControlling>))pictureInPictureReady {
    __weak typeof(self) drawable = self;
    return ^(id<VLCPictureInPictureWindowControlling> pipController){
        drawable.pipController = pipController;
    };
}

#pragma mark - VLCDrawable

- (void)addSubview:(VLCView *)view {
    [self.movieView addSubview:view];
}

- (CGRect)bounds {
    return self.movieView.bounds;
}

#pragma mark - VLCLogging

- (void)setLevel:(VLCLogLevel)level {

}

- (VLCLogLevel)level {
    return kVLCLogLevelDebug;
}

- (void)handleMessage:(nonnull NSString *)message
             logLevel:(VLCLogLevel)level
              context:(nullable VLCLogContext *)context {
    NSLog(@"%@", message);
}

#pragma mark - VLCPictureInPictureMediaControlling

- (int64_t)mediaTime {
    int64_t mediaTime = 
        _mediaPlayer.time.value.integerValue;
    return mediaTime;
}

- (int64_t)mediaLength {
    int64_t mediaLength =
        _mediaPlayer.media.length.value.integerValue;
    return mediaLength;
}

- (void)play {
    [_mediaPlayer play];
}

- (void)pause {
    [_mediaPlayer pause];
}

- (void)seekBy:(int64_t)offset completion:(dispatch_block_t)completion {
    [_mediaPlayer jumpWithOffset:(int)offset completion:completion];
}

- (BOOL)isMediaSeekable {
    return _mediaPlayer.isSeekable;
}

- (BOOL)isMediaPlaying {
    return _mediaPlayer.isPlaying;
}

#pragma mark - VLCMediaPlayerDelegate

- (void)mediaPlayerStateChanged:(VLCMediaPlayerState)newState {
    __block ViewController *vc = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [vc.pipController invalidatePlaybackState];
        vc = nil;
    });
}

- (void)mediaPlayerLengthChanged:(int64_t)length {
    [self.pipController invalidatePlaybackState];
}

@end
