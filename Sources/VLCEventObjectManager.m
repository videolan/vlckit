/*****************************************************************************
 * VLCEventObjectManager.m: VLCKit.framework VLCEventObjectManager implementation
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

#import "VLCEventObjectManager.h"

/**
 * VLCEventObject
 */
@implementation VLCEventObject
{
    void * _descriptor;
    void (^_descriptorReleaseBlock)(void * descriptor);
}

- (instancetype)initWithTarget:(id)target descriptor:(void *)descriptor descriptorReleaseBlock:(void(^)(void * descriptor))block
{
    if (self = [super init]) {
        _weakTarget = target;
        _descriptor = descriptor;
        _descriptorReleaseBlock = [block copy];
    }
    return self;
}

- (void)dealloc
{
    _descriptorReleaseBlock(_descriptor);
}

@end

/**
 * VLCEventObjectManager
 */
@implementation VLCEventObjectManager
{
    NSMutableArray<VLCEventObject *> *_eventObjects;
    dispatch_queue_t _eventObjectsQueue;
    dispatch_queue_t _dispatchAfterQueue;
}

+ (VLCEventObjectManager *)sharedManager
{
    static VLCEventObjectManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[VLCEventObjectManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    if (self = [super init]) {
        
        _eventObjects = [NSMutableArray<VLCEventObject *> array];
        
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                             QOS_CLASS_BACKGROUND,
                                                                             0);
        _eventObjectsQueue = dispatch_queue_create("VLCKit.VLCEventObjectManager.eventObjectsQueue", attr);
        _dispatchAfterQueue = dispatch_queue_create("VLCKit.VLCEventObjectManager.dispatchAfterQueue", attr);
        
    }
    return self;
}

- (VLCEventObject *)registerEventObjectWithTarget:(id)target descriptor:(void *)descriptor descriptorReleaseBlock:(void(^)(void * descriptor))block
{
    VLCEventObject *eventObject = [[VLCEventObject alloc] initWithTarget: target descriptor: descriptor descriptorReleaseBlock: block];
    dispatch_sync(_eventObjectsQueue, ^{
        [self->_eventObjects addObject: eventObject];
    });
    return eventObject;
}

- (void)unregisterEventObject:(VLCEventObject *)eventObject
{
    dispatch_time_t afterTime = dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC);
    dispatch_after(afterTime, _dispatchAfterQueue, ^{
        dispatch_sync(self->_eventObjectsQueue, ^{
            [self->_eventObjects removeObject: eventObject];
        });
    });
}

@end
