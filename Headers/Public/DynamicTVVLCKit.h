/*****************************************************************************
 * DynamicTVVLCKit.h: dynamic library umbrella header
 *****************************************************************************
 * Copyright (C) 2016 VideoLabs SAS
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
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

#import <UIKit/UIKit.h>

//! Project version number for DynamicTVVLCKit.
FOUNDATION_EXPORT double DynamicTVVLCKitVersionNumber;

//! Project version string for DynamicTVVLCKit.
FOUNDATION_EXPORT const unsigned char DynamicTVVLCKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <DynamicTVVLCKit/PublicHeader.h>

#import <DynamicTVVLCKit/VLCAudio.h>
#import <DynamicTVVLCKit/VLCLibrary.h>
#import <DynamicTVVLCKit/VLCMedia.h>
#import <DynamicTVVLCKit/VLCMediaDiscoverer.h>
#import <DynamicTVVLCKit/VLCMediaList.h>
#import <DynamicTVVLCKit/VLCMediaPlayer.h>
#import <DynamicTVVLCKit/VLCMediaListPlayer.h>
#import <DynamicTVVLCKit/VLCMediaThumbnailer.h>
#import <DynamicTVVLCKit/VLCTime.h>
#import <DynamicTVVLCKit/VLCDialogProvider.h>

@class VLCMedia;
@class VLCMediaLibrary;
@class VLCMediaList;
@class VLCTime;
@class VLCVideoView;
@class VLCAudio;
@class VLCMediaThumbnailer;
@class VLCMediaListPlayer;
@class VLCMediaPlayer;
@class VLCDialogProvider;
