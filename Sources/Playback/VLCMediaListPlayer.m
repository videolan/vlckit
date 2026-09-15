/*****************************************************************************
 * VLCMediaListPlayer.m: VLCKit.framework VLCMediaListPlayer implementation
 *****************************************************************************
 * Copyright (C) 2009 Pierre d'Herbemont
 * Partial Copyright (C) 2009-2024 Felix Paul Kühne
 * Copyright (C) 2009-2019 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *          Felix Paul Kühne <fkuehne # videolan.org>
 *          Soomin Lee <bubu # mikan.io>
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

#import <VLCMediaListPlayer.h>
#import <VLCMedia.h>
#import <VLCMediaPlayer.h>
#import <VLCMediaPlayer+Internal.h>
#import <VLCMediaList.h>
#import <VLCLibVLCBridging.h>
#import <VLCLibrary.h>
#import <VLCEventsHandler.h>

@interface VLCMediaListPlayer () {
    void *instance;
    VLCMedia *_rootMedia;
    VLCMediaPlayer *_mediaPlayer;
    VLCMediaList *_mediaList;
    VLCRepeatMode _repeatMode;
    dispatch_queue_t _libVLCBackgroundQueue;
    VLCEventsHandler *_eventsHandler;
}
- (void)mediaListPlayerNextItemSet:(VLCMedia *)media;
- (void)mediaListPlayerStopped;
@end

static void HandleMediaChanged(void *opaque, libvlc_media_t *md)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMedia *media = [[VLCMedia alloc] initWithLibVLCMediaDescriptor:md];
            VLCMediaListPlayer *mediaListPlayer = (VLCMediaListPlayer *)object;
            [mediaListPlayer.mediaPlayer mediaPlayerMediaChanged:media];
            [mediaListPlayer mediaListPlayerNextItemSet: media];
        }];
    }
}

static void HandleStateChanged(void *opaque, libvlc_state_t state)
{
    VLCMediaPlayerState newState;

    switch (state) {
        case libvlc_Playing:
            newState = VLCMediaPlayerStatePlaying;
            break;
        case libvlc_Paused:
            newState = VLCMediaPlayerStatePaused;
            break;
        case libvlc_Stopping:
            newState = VLCMediaPlayerStateStopping;
            break;
        case libvlc_Stopped:
            newState = VLCMediaPlayerStateStopped;
            break;
        case libvlc_Error:
            newState = VLCMediaPlayerStateError;
            break;
        case libvlc_Opening:
            newState = VLCMediaPlayerStateOpening;
            break;

        default:
            VKLog(@"%s: Unknown event", __FUNCTION__);
            return;
    }

    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaListPlayer *mediaListPlayer = (VLCMediaListPlayer *)object;
            VLCMediaPlayer *mediaPlayer = mediaListPlayer.mediaPlayer;

            [mediaPlayer mediaPlayerStateChanged:newState];
            NSNotification *notification = [NSNotification notificationWithName:VLCMediaPlayerStateChangedNotification object:mediaPlayer];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
                [mediaPlayer.delegate mediaPlayerStateChanged:newState];

            if (state == libvlc_Stopped)
                [mediaListPlayer mediaListPlayerStopped];
        }];
    }
}

@implementation VLCMediaListPlayer

- (instancetype)initWithOptions:(nullable NSArray *)options andDrawable:(nullable id)drawable
{
    if (self = [super init]) {
        _libVLCBackgroundQueue = dispatch_queue_create("libvlcQueue", DISPATCH_QUEUE_SERIAL);

        VLCLibrary *library;
        if (options != nil) {
            library = [[VLCLibrary alloc] initWithOptions:options];
        } else
            library = [VLCLibrary sharedLibrary];

        _eventsHandler = [VLCEventsHandler handlerWithObject:self configuration:[VLCLibrary sharedEventsConfiguration]];

        static const struct libvlc_media_player_cbs cbs = {
            .version = 0,
            .on_media_changed = HandleMediaChanged,
            .on_state_changed = HandleStateChanged,
        };

        instance = libvlc_media_list_player_new([library instance],
                                                &cbs, (__bridge void *)_eventsHandler);

        _mediaPlayer = [[VLCMediaPlayer alloc] initWithLibVLCInstance:libvlc_media_list_player_get_media_player(instance) andLibrary:library];
        if (drawable != nil)
            [_mediaPlayer setDrawable:drawable];
    }
    return self;
}

- (instancetype)initWithOptions:(NSArray *)options
{
    return [self initWithOptions:options andDrawable:nil];
}

- (instancetype)init
{
    return [self initWithOptions:nil andDrawable:nil];
}

- (instancetype)initWithDrawable:(id)drawable
{
    return [self initWithOptions:nil andDrawable:drawable];
}

- (void)dealloc
{
    [_mediaPlayer stop];
    libvlc_media_list_player_release(instance);
}

- (VLCMediaPlayer *)mediaPlayer
{
    return _mediaPlayer;
}

- (void)setMediaList:(nullable VLCMediaList *)mediaList
{
    if (_mediaList == mediaList)
        return;
    _mediaList = mediaList;

    libvlc_media_list_player_set_media_list(instance, [mediaList libVLCMediaList]);
    [self willChangeValueForKey:@"rootMedia"];
    _rootMedia = nil;
    [self didChangeValueForKey:@"rootMedia"];
}

- (nullable VLCMediaList *)mediaList
{
    return _mediaList;
}

- (void)setRootMedia:(VLCMedia *)media
{
    if (_rootMedia == media)
        return;
    _rootMedia = nil;

    VLCMediaList *mediaList = [[VLCMediaList alloc] init];
    if (media)
        [mediaList addMedia:media];

    // This will clean rootMedia
    [self setMediaList:mediaList];

    // Thus set rootMedia here.
    _rootMedia = media;

}

- (nullable VLCMedia *)rootMedia
{
    return _rootMedia;
}

- (void)playMedia:(VLCMedia *)media
{
    dispatch_async(_libVLCBackgroundQueue, ^{
        libvlc_media_list_player_play_item(instance, [media libVLCMediaDescriptor]);
    });
}

- (void)play
{
    dispatch_async(_libVLCBackgroundQueue, ^{
        libvlc_media_list_player_play(instance);
    });
}

- (void)pause
{
    dispatch_async(_libVLCBackgroundQueue, ^{
        libvlc_media_list_player_set_pause(instance, 1);
    });
}

- (void)stop
{
    libvlc_media_list_player_stop_async(instance);
}

- (BOOL)next
{
    return libvlc_media_list_player_next(instance) == 0 ? YES : NO;
}

- (BOOL)previous
{
    return libvlc_media_list_player_previous(instance) == 0 ? YES : NO;
}

- (void)playItemAtNumber:(NSNumber *)index
{
    dispatch_async(_libVLCBackgroundQueue, ^{
        VLCMedia *media = [_mediaList mediaAtIndex:[index intValue]];
        _mediaPlayer.media = media;
        libvlc_media_list_player_play_item_at_index(instance, [index intValue]);
    });
}

- (void)setRepeatMode:(VLCRepeatMode)repeatMode
{
    libvlc_playback_mode_t mode;
    switch (repeatMode) {
        case VLCRepeatAllItems:
            mode = libvlc_playback_mode_loop;
            break;
        case VLCDoNotRepeat:
            mode = libvlc_playback_mode_default;
            break;
        case VLCRepeatCurrentItem:
            mode = libvlc_playback_mode_repeat;
            break;
        default:
            NSAssert(0, @"Should not be reached");
            break;
    }
    libvlc_media_list_player_set_playback_mode(instance, mode);

    _repeatMode = repeatMode;
}

- (VLCRepeatMode)repeatMode
{
    return _repeatMode;
}

- (BOOL)isPlaying
{
    return libvlc_media_list_player_is_playing(instance);
}

- (VLCMediaPlayerState)state
{
    return (VLCMediaPlayerState)libvlc_media_list_player_get_state(instance);
}

#pragma mark - Delegate methods

- (void)mediaListPlayerNextItemSet:(VLCMedia *)media
{
    if ([_delegate respondsToSelector:@selector(mediaListPlayer:nextMedia:)]) {
        [_delegate mediaListPlayer:self nextMedia:media];
    }
}

- (void)mediaListPlayerStopped
{
    if ([_delegate respondsToSelector:@selector(mediaListPlayerStopped:)]) {
        [_delegate mediaListPlayerStopped:self];
    }
}

@end
