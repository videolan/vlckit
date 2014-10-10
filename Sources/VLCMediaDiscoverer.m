/*****************************************************************************
 * VLCMediaDiscoverer.m: VLCKit.framework VLCMediaDiscoverer implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007, 2014 VLC authors and VideoLAN
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

#import "VLCMediaDiscoverer.h"
#import "VLCLibrary.h"
#import "VLCLibVLCBridging.h"
#import "VLCEventManager.h"

#include <vlc/libvlc.h>

@interface VLCMediaDiscoverer ()
{
    NSString * _localizedName;
    VLCMediaList * _discoveredMedia;
    void * _mdis;
    BOOL _running;
}
@end

static NSArray * availableMediaDiscoverer = nil;     // Global list of media discoverers

/**
 * Declares call back functions to be used with libvlc event callbacks.
 */
@interface VLCMediaDiscoverer()
{
    VLCLibrary *_privateLibrary;
}
/**
 * libvlc told us that the discoverer is actually running
 */
- (void)_mediaDiscovererStarted;

/**
 * libvlc told us that the discoverer stopped running
 */
- (void)_mediaDiscovererEnded;
@end

/* libvlc event callback */
static void HandleMediaDiscovererStarted(const libvlc_event_t * event, void * user_data)
{
    @autoreleasepool {
        NSLog(@"HandleMediaDiscovererStarted");
        id self = (__bridge id)(user_data);
        [[VLCEventManager sharedManager] callOnMainThreadObject:self
                                                     withMethod:@selector(_mediaDiscovererStarted)
                                           withArgumentAsObject:nil];
    }
}

static void HandleMediaDiscovererEnded( const libvlc_event_t * event, void * user_data)
{
    @autoreleasepool {
        NSLog(@"HandleMediaDiscovererEnded");
        id self = (__bridge id)(user_data);
        [[VLCEventManager sharedManager] callOnMainThreadObject:self
                                                     withMethod:@selector(_mediaDiscovererEnded)
                                           withArgumentAsObject:nil];
    }
}


@implementation VLCMediaDiscoverer
+ (NSArray *)availableMediaDiscoverer
{
    if (!availableMediaDiscoverer) {
        availableMediaDiscoverer = @[[[VLCMediaDiscoverer alloc] initWithName:@"sap"],
                                [[VLCMediaDiscoverer alloc] initWithName:@"upnp"],
                                [[VLCMediaDiscoverer alloc] initWithName:@"freebox"],
                                [[VLCMediaDiscoverer alloc] initWithName:@"video_dir"]];
    }
    return availableMediaDiscoverer;
}

- (instancetype)initWithName:(NSString *)aServiceName
{
    if (self = [super init]) {
        _localizedName = nil;
        _discoveredMedia = nil;

        _privateLibrary = [VLCLibrary sharedLibrary];
        libvlc_retain([_privateLibrary instance]);

        _mdis = libvlc_media_discoverer_new_from_name([_privateLibrary instance],
                                                     [aServiceName UTF8String]);
        NSAssert(_mdis, @"No such media discoverer");
        libvlc_event_manager_t * p_em = libvlc_media_discoverer_event_manager(_mdis);
        libvlc_event_attach(p_em, libvlc_MediaDiscovererStarted, HandleMediaDiscovererStarted, (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaDiscovererEnded,   HandleMediaDiscovererEnded,   (__bridge void *)(self));

        _running = libvlc_media_discoverer_is_running(_mdis);
    }
    return self;
}

- (void)dealloc
{
    libvlc_event_manager_t *em = libvlc_media_list_event_manager(_mdis);
    libvlc_event_detach(em, libvlc_MediaDiscovererStarted, HandleMediaDiscovererStarted, (__bridge void *)(self));
    libvlc_event_detach(em, libvlc_MediaDiscovererEnded,   HandleMediaDiscovererEnded,   (__bridge void *)(self));
    [[VLCEventManager sharedManager] cancelCallToObject:self];

    libvlc_media_discoverer_release( _mdis );

    libvlc_release(_privateLibrary.instance);

}

- (VLCMediaList *) discoveredMedia
{
    if (_discoveredMedia)
        return _discoveredMedia;

    libvlc_media_list_t * p_mlist = libvlc_media_discoverer_media_list( _mdis );
    VLCMediaList * ret = [VLCMediaList mediaListWithLibVLCMediaList:p_mlist];
    libvlc_media_list_release( p_mlist );

    _discoveredMedia = ret;
    return _discoveredMedia;
}

- (NSString *)localizedName
{
    if (_localizedName)
        return _localizedName;

    char * name = libvlc_media_discoverer_localized_name( _mdis );
    if (name) {
        _localizedName = @(name);
        free( name );
    }
    return _localizedName;
}

- (BOOL)isRunning
{
    return _running;
}

- (void)_mediaDiscovererStarted
{
    [self willChangeValueForKey:@"running"];
    _running = YES;
    [self didChangeValueForKey:@"running"];
}

- (void)_mediaDiscovererEnded
{
    [self willChangeValueForKey:@"running"];
    _running = NO;
    [self didChangeValueForKey:@"running"];
}
@end
