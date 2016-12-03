/*****************************************************************************
 * DynamicMobileVLCKit.h: dynamic library umbrella header
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

//! Project version number for DynamicMobileVLCKit.
FOUNDATION_EXPORT double DynamicMobileVLCKitVersionNumber;

//! Project version string for DynamicMobileVLCKit.
FOUNDATION_EXPORT const unsigned char DynamicMobileVLCKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <DynamicMobileVLCKit/PublicHeader.h>

#import <DynamicMobileVLCKit/VLCAudio.h>
#import <DynamicMobileVLCKit/VLCLibrary.h>
#import <DynamicMobileVLCKit/VLCMedia.h>
#import <DynamicMobileVLCKit/VLCMediaDiscoverer.h>
#import <DynamicMobileVLCKit/VLCMediaList.h>
#import <DynamicMobileVLCKit/VLCMediaPlayer.h>
#import <DynamicMobileVLCKit/VLCMediaListPlayer.h>
#import <DynamicMobileVLCKit/VLCMediaThumbnailer.h>
#import <DynamicMobileVLCKit/VLCTime.h>
#import <DynamicMobileVLCKit/VLCDialogProvider.h>

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
