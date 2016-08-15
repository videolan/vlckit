/*****************************************************************************
 * VLCKit: VLCExtensions
 *****************************************************************************
 * Copyright (C) 2010-2014 Pierre d'Herbemont and VideoLAN
 *
 * Authors: Pierre d'Herbemont
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
#import <vlc_extensions.h>

/**
 * wrapper class for lua extensions within VLCKit
 */
@interface VLCExtension : NSObject

/**
 * initializer for wrapper class
 * \param instance the extension_t instance to init the wrapper with
 * \deprecated will be removed in the next release
 */
- (instancetype)initWithInstance:(struct extension_t *)instance NS_DESIGNATED_INITIALIZER __attribute__((deprecated)); // FIXME: Should be internal

/**
 * the extension instance used to init the wrapper with
 * \deprecated will be removed in the next release
 */
@property (NS_NONATOMIC_IOSONLY, readonly) struct extension_t *instance __attribute__((deprecated)); // FIXME: Should be internal

/**
 * technical name of the extension
 * \deprecated will be removed in the next release
 */
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *name __attribute__((deprecated));

/**
 * user-visible name of the extension
 * \deprecated will be removed in the next release
 */
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *title __attribute__((deprecated));

@end
