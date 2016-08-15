/*****************************************************************************
 * VLCKit: VLCExtensionsManager
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

@class VLCExtension;
@class VLCMediaPlayer;

/**
 * manager class for lua extensions within VLC
 */
@interface VLCExtensionsManager : NSObject

/**
 * singleton manager instance
 * \deprecated will be removed in the next release
 */
+ (VLCExtensionsManager *)sharedManager __attribute__((deprecated));

/**
 * list of available extensions
 * \deprecated will be removed in the next release
 */
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *extensions __attribute__((deprecated));

/**
 * start execution of a given extension instance
 * \param extension the extension to run
 * \deprecated will be removed in the next release
 */
- (void)runExtension:(VLCExtension *)extension __attribute__((deprecated));

/**
 * player instance to use with the extensions
 * \deprecated will be removed in the next release
 */
@property (readwrite, strong) VLCMediaPlayer *mediaPlayer __attribute__((deprecated));

@end
