/*****************************************************************************
 * VLCMediaListPlayer.h: VLCKit.framework VLCMediaListPlayer implementation
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

@class VLCMedia, VLCMediaPlayer, VLCMediaList;

/**
 * VLCRepeatMode
 * (don't repeat anything, repeat one, repeat all)
 */
typedef NS_ENUM(NSInteger, VLCRepeatMode) {
    VLCDoNotRepeat,
    VLCRepeatCurrentItem,
    VLCRepeatAllItems
};

@interface VLCMediaListPlayer : NSObject

@property (readwrite) VLCMediaList *mediaList;

/**
 * rootMedia - Use this method to play a media and its subitems.
 * This will erase mediaList.
 * Setting mediaList will erase rootMedia.
 */
@property (readwrite) VLCMedia *rootMedia;
@property (readonly) VLCMediaPlayer *mediaPlayer;

- (instancetype)initWithDrawable:(id)drawable;
- (instancetype)initWithOptions:(NSArray *)options;
- (instancetype)initWithOptions:(NSArray *)options andDrawable:(id)drawable;

/**
 * Basic play, pause and stop are here. For other methods, use the mediaPlayer.
 */
- (void)play;
- (void)pause;
- (void)stop;

/**
 * previous, next, play item at index
 * \returns YES on success, NO if there is no such item
 */
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL next;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL previous;
- (BOOL)playItemAtIndex:(int)index;

/**
 * Playmode selection (don't repeat anything, repeat one, repeat all)
 * See VLCRepeatMode.
 */

@property (readwrite) VLCRepeatMode repeatMode;

/**
 * media must be in the current media list.
 */
- (void)playMedia:(VLCMedia *)media;

@end
