/*****************************************************************************
 * VLCMediaListPlayer.m: VLCKit.framework VLCMediaListPlayer implementation
 *****************************************************************************
 * Copyright (C) 2009 Pierre d'Herbemont
 * Partial Copyright (C) 2009-2013 Felix Paul Kühne
 * Copyright (C) 2009-2013 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *          Felix Paul Kühne <fkuehne # videolan.org
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

#import "VLCMediaListPlayer.h"
#import "VLCMedia.h"
#import "VLCMediaPlayer.h"
#import "VLCMediaList.h"
#import "VLCLibVLCBridging.h"

@interface VLCMediaListPlayer () {
    void *instance;
    VLCMedia *_rootMedia;
    VLCMediaPlayer *_mediaPlayer;
    VLCMediaList *_mediaList;
    VLCRepeatMode _repeatMode;
}
@end

@implementation VLCMediaListPlayer

- (instancetype)initWithOptions:(NSArray *)options
{
        if (self = [super init]) {
            _mediaPlayer = [[VLCMediaPlayer alloc] initWithOptions:options];

            instance = libvlc_media_list_player_new([_mediaPlayer.libraryInstance instance]);
            libvlc_media_list_player_set_media_player(instance, [_mediaPlayer libVLCMediaPlayer]);
        }
        return self;

}

- (instancetype)init
{
    return [self initWithOptions:nil];
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

- (void)setMediaList:(VLCMediaList *)mediaList
{
    if (_mediaList == mediaList)
        return;
    _mediaList = mediaList;

    libvlc_media_list_player_set_media_list(instance, [mediaList libVLCMediaList]);
    [self willChangeValueForKey:@"rootMedia"];
    _rootMedia = nil;
    [self didChangeValueForKey:@"rootMedia"];
}

- (VLCMediaList *)mediaList
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

- (VLCMedia *)rootMedia
{
    return _rootMedia;
}

- (void)playMedia:(VLCMedia *)media
{
    libvlc_media_list_player_play_item(instance, [media libVLCMediaDescriptor]);
}

- (void)play
{
    libvlc_media_list_player_play(instance);
}

- (void)pause
{
    libvlc_media_list_player_pause(instance);
}

- (void)stop
{
    libvlc_media_list_player_stop(instance);
}

- (BOOL)next
{
    return libvlc_media_list_player_next(instance) == 0 ? YES : NO;
}

- (BOOL)previous
{
    return libvlc_media_list_player_previous(instance) == 0 ? YES : NO;
}

- (BOOL)playItemAtIndex:(int)index
{
    return libvlc_media_list_player_play_item_at_index(instance, index) == 0 ? YES : NO;
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
@end
