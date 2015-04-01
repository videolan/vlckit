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

@class VLCMediaList;
@class VLCMediaDiscoverer;

/**
 * VLCMediaDiscovererDelegate
 */

@protocol VLCMediaDiscovererDelegate <NSObject>
@optional

/**
 * delegate method triggered when a discoverer was started
 *
 * \param the discoverer that was started
 */
- (void)discovererStarted:(VLCMediaDiscoverer *)theDiscoverer;

/**
 * delegate method triggered when a discoverer was stopped
 *
 * \param the discoverer that was stopped
 */
- (void)discovererStopped:(VLCMediaDiscoverer *)theDiscoverer;

@end

/**
 * VLCMediaDiscoverer
 */

@interface VLCMediaDiscoverer : NSObject

/**
 * delegate property to listen to start/stop events
 */
@property (weak, readwrite) id<VLCMediaDiscovererDelegate> delegate;

/**
 * Maintains a list of available media discoverers.  This list is populated as new media
 * discoverers are created.
 * \return A list of available media discoverers.
 */
+ (NSArray *)availableMediaDiscoverer;

/* Initializers */
/**
 * Initializes new object with specified name.
 * \param aServiceName Name of the service for this VLCMediaDiscoverer object.
 * \returns Newly created media discoverer.
 */
- (instancetype)initWithName:(NSString *)aServiceName;

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
