/*****************************************************************************
 * VLCKit: VLCExtensions
 *****************************************************************************
 * Copyright (C) 2010-2012 Pierre d'Herbemont and VideoLAN
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


@interface VLCExtension : NSObject {
    struct extension_t *_instance;
}

- (id)initWithInstance:(struct extension_t *)instance; // FIXME: Should be internal
- (struct extension_t *)instance; // FIXME: Should be internal

- (NSString *)name;
- (NSString *)title;

@end
