/*****************************************************************************
 * VLCEventsConfiguration.m: [Mobile/TV]VLCKit VLCEventsHandler implementation
 *****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Maxime Chapelet <umxprime # videolabs.io>
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

#import "../Headers/Public/VLCEventsConfiguration.h"

@implementation VLCEventsDefaultConfiguration

- (dispatch_queue_t _Nullable)dispatchQueue {
    return nil;
}

- (BOOL)isAsync {
    return NO;
}

@end

@implementation VLCEventsLegacyConfiguration

- (dispatch_queue_t _Nullable)dispatchQueue {
    return dispatch_get_main_queue();
}

- (BOOL)isAsync {
    return YES;
}

@end
