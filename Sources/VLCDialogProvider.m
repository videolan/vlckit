/*****************************************************************************
 * VLCDialogProvider.m: an implementation of the libvlc dialog API
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

#import <VLCDialogProvider.h>
#import <VLCCustomDialogProvider.h>

#if TARGET_OS_IPHONE
    #if !(TARGET_OS_TV || (defined(TARGET_OS_VISION) && TARGET_OS_VISION))
        #import <VLCiOSLegacyDialogProvider.h>
    #endif
    #import <VLCEmbeddedDialogProvider.h>
#endif // TARGET_OS_IPHONE

/* We are the root of a class cluster, not much to see */

@implementation VLCDialogProvider

- (nullable instancetype)initWithLibrary:(nullable VLCLibrary *)library customUI:(BOOL)customUI
{
#if TARGET_OS_IPHONE
    if (customUI)
        return [[VLCCustomDialogProvider alloc] initWithLibrary:library];

    #if !(TARGET_OS_TV || (defined(TARGET_OS_VISION) && TARGET_OS_VISION))
        if ([UIAlertController class]) {
            return [[VLCEmbeddedDialogProvider alloc] initWithLibrary:library];
        } else {
            return [[VLCiOSLegacyDialogProvider alloc] initWithLibrary:library];
        }
    #else
        return [[VLCEmbeddedDialogProvider alloc] initWithLibrary:library];
    #endif
#else
    if (customUI) {
        return [[VLCCustomDialogProvider alloc] initWithLibrary:library];
    } else {
        NSLog(@"YOU NEED TO IMPLEMENT YOUR UI YOURSELF ON THE MAC");
        return nil;
    }
#endif
}

- (void)postAction:(int)buttonNumber forDialogReference:(NSValue *)dialogReference
{
    // implemented by respective child class
}

- (void)postUsername:(NSString *)username andPassword:(NSString *)password forDialogReference:(NSValue *)dialogReference store:(BOOL)store
{
    // implemented by respective child class
}

- (void)dismissDialogWithReference:(NSValue *)dialogReference
{
    // implemented by respective child class
}

@end
