/*****************************************************************************
 * VLCEventsHandler.m: [Mobile/TV]VLCKit VLCEventsHandler implementation
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

#import "../Headers/Internal/VLCEventsHandler.h"
#import "../Headers/Public/VLCEventsConfiguration.h"

@implementation VLCEventsHandler {
    id<VLCEventsConfiguring> _configuration;
    
    /// Queue used to release asynchronously the retained object
    dispatch_queue_t _releaseQueue;
}

+ (instancetype)handlerWithObject:(id)object
                    configuration:(id<VLCEventsConfiguring> _Nullable)configuration {
    return [[self alloc] initWithObject:object
                          configuration:configuration];
}

- (instancetype)initWithObject:(id)object
                 configuration:(id<VLCEventsConfiguring> _Nullable)configuration {
    self = [super init];
    if (self) {
        _object = object;
        _configuration = configuration;
        // FIXME: on iOS 10/macOS 10.12/tvOS 10 we could use DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
        _releaseQueue = dispatch_queue_create("handler.releaseQueue", attr);
    }
    return self;
}

- (void)handleEvent:(void (^)(id))handle {
    __block id object = _object;
    if (!object) {
        // Object is already nil, no need to handle the event
        return;
    }
    dispatch_queue_t releaseQueue = _releaseQueue;
    dispatch_block_t block = ^{
        handle(object);
        dispatch_async(releaseQueue, ^{
            // TODO: check if autoreleasepool is needed there
            @autoreleasepool {
                object = nil;
            }
        });
    };
    if (_configuration.dispatchQueue) {
        if (_configuration.isAsync)
            dispatch_async(_configuration.dispatchQueue, block);
        else
            dispatch_sync(_configuration.dispatchQueue, block);
    } else {
        block();
    }
}

@end
