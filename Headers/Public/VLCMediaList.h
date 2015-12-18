/*****************************************************************************
 * VLCMediaList.h: VLCKit.framework VLCMediaList header
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2015 Felix Paul Kühne
 * Copyright (C) 2007, 2015 VLC authors and VideoLAN
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

#import <Foundation/Foundation.h>
#import "VLCMedia.h"

/* Notification Messages */
extern NSString *const VLCMediaListItemAdded;
extern NSString *const VLCMediaListItemDeleted;

@class VLCMedia;
@class VLCMediaList;

/**
 * VLCMediaListDelegate
 */
@protocol VLCMediaListDelegate
@optional
/**
 * delegate method triggered when a media was added to the list
 *
 * \param the media list
 * \param the media object that was added
 * \param the index the media object was added at
 */
- (void)mediaList:(VLCMediaList *)aMediaList mediaAdded:(VLCMedia *)media atIndex:(NSInteger)index;

/**
 * delegate method triggered when a media was removed from the list
 *
 * \param the media list
 * \param the index a media item was deleted at
 */
- (void)mediaList:(VLCMediaList *)aMediaList mediaRemovedAtIndex:(NSInteger)index;
@end

/**
 * VLCMediaList
 */
@interface VLCMediaList : NSObject

- (instancetype)initWithArray:(NSArray *)array;

/* Operations */
/**
 * lock the media list from being edited by another thread
 */
- (void)lock;

/**
 * unlock the media list from being edited by another thread
 */
- (void)unlock;

/**
 * add a media to a read-write list
 *
 * \param the media object to add
 * \return the index of the newly added media
 * \note this function silently fails if the list is read-only
 */
- (NSInteger)addMedia:(VLCMedia *)media;

/**
 * add a media to a read-write list at a given position
 *
 * \param the media object to add
 * \param the index where to add the given media
 * \note this function silently fails if the list is read-only
 */
- (void)insertMedia:(VLCMedia *)media atIndex:(NSInteger)index;

/**
 * remove a media from a given position
 *
 * \param the index of the media to remove
 * \note this function silently fails if the list is read-only
 */
- (void)removeMediaAtIndex:(NSInteger)index;

/**
 * retrieve a media from a given position
 *
 * \param the index of the media you want
 * \return the media object
 */
- (VLCMedia *)mediaAtIndex:(NSInteger)index;

/**
 * retrieve the position of a media item
 *
 * \param the media object to search for
 * \return the index position of the media in the list or -1 if not found
 */
- (NSInteger)indexOfMedia:(VLCMedia *)media;

/* Properties */
/**
 * number of media items in the list
 * \return the number of media objects
 */
@property (readonly) NSInteger count;

/**
 * delegate property to listen to addition/removal events
 */
@property (weak, nonatomic) id delegate;

/**
 * read-only property to check if the media list is writable or not
 * \return boolean value if the list is read-only
 */
@property (readonly) BOOL isReadOnly;

@end
