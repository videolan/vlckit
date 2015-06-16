/*****************************************************************************
 * VLCMediaDiscoverer.h: VLCKit.framework VLCMediaDiscoverer header
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2015 Felix Paul Kühne
 * Copyright (C) 2007, 2015 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *          Felix Paul Kühne <fkuehne # videolan.org>
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
#import "VLCMediaList.h"

@class VLCLibrary;
@class VLCMediaList;
@class VLCMediaDiscoverer;

/**
 * VLCMediaDiscoverer
 */

@interface VLCMediaDiscoverer : NSObject

@property (nonatomic, readonly) VLCLibrary *libraryInstance;

/**
 * \return returns an empty array, will be removed in subsequent releases
 */
+ (NSArray *)availableMediaDiscoverer __attribute__((deprecated));

/* Initializers */
/**
 * Initializes new object with specified name.
 * \param aServiceName Name of the service for this VLCMediaDiscoverer object.
 * \returns Newly created media discoverer.
 * \note with VLCKit 3.0 and above, you need to start the discoverer explicitly after creation
 */
- (instancetype)initWithName:(NSString *)aServiceName;

/**
 * start media discovery
 * \returns -1 if start failed, otherwise 0
 */
- (int)startDiscoverer;

/**
 * stop media discovery
 */
- (void)stopDiscoverer;

/**
 * a read-only property to retrieve the list of discovered media items
 */
@property (weak, readonly) VLCMediaList *discoveredMedia;

/**
 * returns the localized name of the discovery module if available, otherwise in US English
 */
@property (readonly, copy) NSString *localizedName;

/**
 * read-only property to check if the discovery service is active
 * \return boolean value
 */
@property (readonly) BOOL isRunning;
@end
