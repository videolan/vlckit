/*****************************************************************************
 * VLCVideoView.h: VLCKit.framework VLCVideoView header
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
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

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

/**
 * a custom view suitable for video rendering in AppKit environments
 */
@interface VLCVideoView : NSView

/* Properties */
/**
* NSColor to set as the view background if no video is being rendered
*/
@property (nonatomic, copy) NSColor *backColor;

/**
 * Is a video being rendered in this layer?
 * \return the BOOL value
 */
@property (nonatomic, readonly) BOOL hasVideo;
/**
 * Should the video fill the screen by adding letterboxing or stretching?
 * \return the BOOL value
 */
@property (nonatomic) BOOL fillScreen;

@end
