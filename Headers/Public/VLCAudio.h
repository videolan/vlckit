/*****************************************************************************
 * VLCAudio.h: VLCKit.framework VLCAudio header
 *****************************************************************************
 * Copyright (C) 2007 Faustino E. Osuna
 * Copyright (C) 2007, 2014 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Faustino E. Osuna <enrique.osuna # gmail.com>
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

#import <Foundation/Foundation.h>

/* Notification Messages */
/**
 * Standard notification messages that are emitted by VLCAudio object.
 */
extern NSString *const VLCMediaPlayerVolumeChanged;

@class VLCMediaPlayer;

/**
 * TODO: Documentation VLCAudio
 */
@interface VLCAudio : NSObject

/* Properties */
@property (getter=isMuted) BOOL muted;
@property (assign) int volume;

- (void)setMute:(BOOL)value __attribute__((deprecated));

- (void)volumeDown;
- (void)volumeUp;
@end
