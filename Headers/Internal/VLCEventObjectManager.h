/*****************************************************************************
 * VLCEventObjectManager.h: VLCKit.framework VLCEventObjectManager header
 *****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
 * $Id$
 *
 * Authors:
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

/**
 * VLCEventObject
 */
@interface VLCEventObject : NSObject

@property(nonatomic, weak, nullable, readonly) id weakTarget;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

/**
 * VLCEventObjectManager
 */
@interface VLCEventObjectManager : NSObject

@property(class, nonatomic, readonly) VLCEventObjectManager *sharedManager;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (VLCEventObject *)registerEventObjectWithTarget:(id)target descriptor:(void *)descriptor descriptorReleaseBlock:(void(^)(void * descriptor))block;

- (void)unregisterEventObject:(VLCEventObject *)eventObject;

@end

NS_ASSUME_NONNULL_END
