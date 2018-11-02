/*****************************************************************************
 * VLCTranscoder.m
 *****************************************************************************
 * Copyright © 2018 VLC authors, VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee<bubu@mikan.io>
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

#import "VLCTranscoder.h"

#import "VLCEventManager.h"
#import "VLCLibrary.h"
#import "VLCLibVLCBridging.h"

#include <vlc/vlc.h>

@interface VLCTranscoder()
{
    libvlc_media_player_t *_p_mp; //player instance used for transcoding
    dispatch_queue_t _libVLCTranscoderQueue;
}

- (void)registerObserversForMuxWithPlayer:(libvlc_media_player_t *)player;
- (void)unregisterObserversForMuxWithPlayer:(libvlc_media_player_t *)player;

@end

@implementation VLCTranscoder

- (instancetype)init
{
    if (self = [super init]) {
        _libVLCTranscoderQueue = dispatch_queue_create("libVLCTranscoderQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)muxSubtitleFile:(NSString *)srtPath toMp4File:(NSString *)mp4Path outputPath:(NSString *)outputPath
{
    //check for file type

    libvlc_media_t* p_media = libvlc_media_new_path([[VLCLibrary sharedLibrary] instance], [mp4Path UTF8String]);

    NSString *transcodingOptions = [NSString stringWithFormat:@":sout=#transcode{vcodec=h264,width=720,height=480,venc=avcodec{codec=h264_videotoolbox},acodec=mpga,ab=128,channels=2,samplerate=44100,soverlay}:file{dst='%@',mux=mp4}", outputPath];

    libvlc_media_add_option(p_media, [[NSString stringWithFormat:@":sub-file=%@", srtPath] UTF8String]);
    libvlc_media_add_option(p_media, [transcodingOptions UTF8String]);

    _p_mp = libvlc_media_player_new_from_media( p_media );

    [self registerObserversForMuxWithPlayer:_p_mp];

    return libvlc_media_player_play( _p_mp ) == 0;
}

- (void)registerObserversForMuxWithPlayer:(libvlc_media_player_t *)player
{
    __block libvlc_event_manager_t * p_em = libvlc_media_player_event_manager(player);
    if (!p_em)
        return;

    dispatch_sync(_libVLCTranscoderQueue,^{
        libvlc_event_attach(p_em, libvlc_MediaPlayerPaused,
                            HandleMuxMediaInstanceStateChanged, (__bridge void *)(self));
    });
}

- (void)unregisterObserversForMuxWithPlayer:(libvlc_media_player_t *)player
{
    libvlc_event_manager_t * p_em = libvlc_media_player_event_manager(player);
    if (!p_em)
        return;

    libvlc_event_detach(p_em, libvlc_MediaPlayerPaused,
                        HandleMuxMediaInstanceStateChanged, (__bridge void *)(self));
}

- (void)mediaPlayerStateChangeForMux:(NSNumber *)newState
{
    if (_p_mp) {
        [self unregisterObserversForMuxWithPlayer:_p_mp];
        libvlc_media_player_stop( _p_mp );
    }
}

static void HandleMuxMediaInstanceStateChanged(const libvlc_event_t * event, void * self)
{
    VLCMediaPlayerState newState;

    if (event->type == libvlc_MediaPlayerPaused) {
        newState = VLCMediaPlayerStatePaused;

        @autoreleasepool {
            [[VLCEventManager sharedManager] callOnMainThreadObject:(__bridge id)(self)
                                                         withMethod:@selector(mediaPlayerStateChangeForMux:)
                                               withArgumentAsObject:@(newState)];
        }
    }
}

- (void)dealloc
{
    libvlc_media_player_release(_p_mp);
}
@end
