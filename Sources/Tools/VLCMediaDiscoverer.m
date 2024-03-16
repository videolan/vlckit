/*****************************************************************************
 * VLCMediaDiscoverer.m: VLCKit.framework VLCMediaDiscoverer implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2014-2017 Felix Paul Kühne
 * Copyright (C) 2007, 2015 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *          Felix Paul Kühne <fkuehne # videolan dot org>
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

#import <VLCMediaDiscoverer.h>
#import <VLCLibrary.h>
#import <VLCLibVLCBridging.h>

#include <vlc/vlc.h>
#include <vlc/libvlc.h>
#include <vlc/libvlc_media_discoverer.h>

NSString *const VLCMediaDiscovererName = @"VLCMediaDiscovererName";
NSString *const VLCMediaDiscovererLongName = @"VLCMediaDiscovererLongName";
NSString *const VLCMediaDiscovererCategory = @"VLCMediaDiscovererCategory";

@interface VLCMediaDiscoverer ()
{
    VLCMediaList *_discoveredMedia;
    libvlc_media_discoverer_t *_mdis;

    VLCLibrary *_privateLibrary;
    dispatch_queue_t _libVLCBackgroundQueue;
}
@end

@implementation VLCMediaDiscoverer
@synthesize libraryInstance = _privateLibrary;

+ (NSArray *)availableMediaDiscovererForCategoryType:(VLCMediaDiscovererCategoryType)categoryType
{
    libvlc_media_discoverer_description_t **discoverers;
    ssize_t numberOfDiscoverers = libvlc_media_discoverer_list_get([VLCLibrary sharedInstance], (libvlc_media_discoverer_category_t)categoryType, &discoverers);

    if (numberOfDiscoverers == 0) {
        libvlc_media_discoverer_list_release(discoverers, numberOfDiscoverers);
        return @[];
    }

    NSMutableArray *mutArray = [NSMutableArray arrayWithCapacity:numberOfDiscoverers];
    for (unsigned u = 0; u < numberOfDiscoverers; u++) {
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                              discoverers[u]->psz_name ? [NSString stringWithUTF8String:discoverers[u]->psz_name] : @"",
                              VLCMediaDiscovererName,
                              discoverers[u]->psz_longname ? [NSString stringWithUTF8String:discoverers[u]->psz_longname] : @"",
                              VLCMediaDiscovererLongName,
                              @(discoverers[u]->i_cat),
                              VLCMediaDiscovererCategory,
                              nil];
        [mutArray addObject:dict];
    }

    libvlc_media_discoverer_list_release(discoverers, numberOfDiscoverers);
    return [mutArray copy];
}

- (instancetype)initWithName:(NSString *)aServiceName
{
    return [self initWithName:aServiceName libraryInstance:nil];
}

- (instancetype)initWithName:(NSString *)aServiceName libraryInstance:(nullable VLCLibrary *)libraryInstance
{
    if (self = [super init]) {
        _discoveredMedia = nil;
        _libVLCBackgroundQueue = dispatch_queue_create("libvlcQueue", DISPATCH_QUEUE_SERIAL);

        if (libraryInstance != nil) {
            _privateLibrary = libraryInstance;
        } else {
            _privateLibrary = [VLCLibrary sharedLibrary];
        }

        _mdis = libvlc_media_discoverer_new([_privateLibrary instance],
                                            [aServiceName UTF8String]);

        if (_mdis == NULL) {
            VKLog(@"media discovery initialization failed, maybe no such module?");
            return NULL;
        }
    }
    return self;
}

- (void)dealloc
{
    _discoveredMedia = nil;

    if (_mdis) {
        if (libvlc_media_discoverer_is_running(_mdis))
            libvlc_media_discoverer_stop(_mdis);
        libvlc_media_discoverer_release(_mdis);
    }
}

- (int)startDiscoverer
{
    int returnValue = libvlc_media_discoverer_start(_mdis);
    if (returnValue == -1) {
        VKLog(@"media discovery start failed");
        return returnValue;
    }

    libvlc_media_list_t *p_mlist = libvlc_media_discoverer_media_list(_mdis);
    VLCMediaList *ret = [VLCMediaList mediaListWithLibVLCMediaList:p_mlist];
    libvlc_media_list_release(p_mlist);

    _discoveredMedia = ret;

    return returnValue;
}

- (void)stopDiscoverer
{
    if (![self isRunning]) {
        return;
    }

    dispatch_async(_libVLCBackgroundQueue, ^{
        libvlc_media_discoverer_stop(_mdis);
    });
}

- (nullable VLCMediaList *)discoveredMedia
{
    return _discoveredMedia;
}

- (BOOL)isRunning
{
    return libvlc_media_discoverer_is_running(_mdis);
}

@end
