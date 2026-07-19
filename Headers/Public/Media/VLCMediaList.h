/*****************************************************************************
 * VLCMediaList.h: VLCKit.framework VLCMediaList header
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2015, 2024 Felix Paul Kühne
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

NS_ASSUME_NONNULL_BEGIN

@class VLCMedia;
@class VLCMediaList;

/**
 * criteria to sort a media list by
 * \see -[VLCMediaList mediaSortedByCriteria:ascending:]
 */
typedef NS_ENUM(NSUInteger, VLCMediaListSortCriteria) {
    VLCMediaListSortCriteriaDefault,
    VLCMediaListSortCriteriaName,
    VLCMediaListSortCriteriaModificationDate,
    VLCMediaListSortCriteriaSize,
};

/**
 * VLCMediaList
 */
OBJC_VISIBLE
@interface VLCMediaList : NSObject

/**
 * initializer with a set of VLCMedia instances
 * \param array the NSArray of VLCMedia instances
 * \return instance of VLCMediaList equipped with the VLCMedia instances
 * \see VLCMedia
 */
- (instancetype)initWithArray:(nullable NSArray<VLCMedia *> *)array;

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
 * \param media the media object to add
 * \return the index of the newly added media
 * \note this function silently fails if the list is read-only
 */
- (NSUInteger)addMedia:(VLCMedia *)media;

/**
 * add a media to a read-write list at a given position
 *
 * \param media the media object to add
 * \param index the index where to add the given media
 * \note this function silently fails if the list is read-only
 */
- (void)insertMedia:(VLCMedia *)media atIndex:(NSUInteger)index;

/**
 * remove media at position index and return true if the operation was successful.
 * An unsuccessful operation occurs when the index is greater than the medialists count
 *
 * \param index the index of the media to remove
 * \return boolean result of the removal operation
 * \note this function silently fails if the list is read-only
 */
- (BOOL)removeMediaAtIndex:(NSUInteger)index;

/**
 * retrieve a media from a given position
 *
 * \param index the index of the media you want
 * \return the media object
 */
- (nullable VLCMedia *)mediaAtIndex:(NSUInteger)index;

/**
 * retrieve the position of a media item
 *
 * \param media the media object to search for
 * \return The lowest index of the provided media in the list
 * If media does not exist in the list, returns NSNotFound.
 */
- (NSUInteger)indexOfMedia:(VLCMedia *)media;

/**
 * return the list's media sorted by the given criteria
 *
 * \param criteria the sort criteria, see VLCMediaListSortCriteria
 * \param ascending sort in ascending (YES) or descending (NO) order
 * \return a new array holding the list's media in the requested order
 *
 * \note the receiver is not modified
 * \note VLCMediaListSortCriteriaDefault returns the media in the list's
 *       existing order and ignores the ascending parameter
 * \note media lacking the requested value (e.g. an unavailable modification
 *       date or size) are ordered last, regardless of the sort direction
 */
- (NSArray<VLCMedia *> *)mediaSortedByCriteria:(VLCMediaListSortCriteria)criteria ascending:(BOOL)ascending;

/* Properties */
/**
 * count number of media items in the list
 * \return the number of media objects
 */
@property (readonly) NSInteger count;

/**
 * read-only property to check if the media list is writable or not
 * \return boolean value if the list is read-only
 */
@property (readonly) BOOL isReadOnly;

/**
 * read-only property to check if the media list is empty or not
 * \return boolean value if the list is empty or not.
 */
@property (readonly) BOOL isEmpty;

@end

NS_ASSUME_NONNULL_END
