/*****************************************************************************
 * VLCMediaLibrary.h: VLCKit.framework VLCMediaDiscoverer header
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007, 2014 VLC authors and VideoLAN
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

#import "VLCMediaList.h"

@class VLCMediaList;

/**
 * media library stub
 */
@interface VLCMediaLibrary : NSObject

/**
 * library singleton
 * \deprecated will be removed in the next release
*/
+ (VLCMediaLibrary*)sharedMediaLibrary __attribute__((deprecated));

/**
 * list of all media
 * \deprecated will be removed in the next release
 */
@property (nonatomic, readonly, strong) VLCMediaList * allMedia __attribute__((deprecated));

@end
