/*****************************************************************************
 * VLCRendererDiscoverer.m
 *****************************************************************************
 * Copyright © 2018 VLC authors, VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee<bubu@mikan.io>
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

#import <VLCRendererDiscoverer.h>
#import <VLCLibrary.h>
#import <VLCLibVLCBridging.h>
#import <VLCEventsHandler.h>

@interface VLCRendererDiscoverer()
{
    libvlc_renderer_discoverer_t *_rendererDiscoverer;
    NSMutableArray<VLCRendererItem *> *_rendererItems;
    VLCEventsHandler* _eventsHandler;
}

- (void)itemAdded:(VLCRendererItem *)item;

- (void)itemDeleted:(VLCRendererItem *)item;

@end

#pragma mark - LibVLC event callbacks

static void HandleRendererDiscovererItemAdded(const libvlc_event_t *event, void *opaque)
{
    @autoreleasepool {
        VLCRendererItem *renderer = [[VLCRendererItem alloc] initWithRendererItem:event->u.renderer_discoverer_item_added.item];
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler*)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCRendererDiscoverer *rendererDiscoverer = (VLCRendererDiscoverer *)object;
            [rendererDiscoverer itemAdded: renderer];
        }];
    }
}

static void HandleRendererDiscovererItemDeleted(const libvlc_event_t *event, void *opaque)
{
    @autoreleasepool {
        VLCRendererItem *renderer = [[VLCRendererItem alloc] initWithRendererItem:event->u.renderer_discoverer_item_deleted.item];
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler*)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCRendererDiscoverer *rendererDiscoverer = (VLCRendererDiscoverer *)object;
            [rendererDiscoverer itemDeleted:renderer];
        }];
    }
}

#pragma mark - VLCRendererDiscovererDescription

@implementation VLCRendererDiscovererDescription

- (instancetype)initWithName:(NSString *)name longName:(NSString *)longName
{
    self = [super init];
    if (self) {
        NSAssert(name, @"VLCRendererDiscovererDescription: name is NULL");
        _name = name;

        NSAssert(longName, @"VLCRendererDiscovererDescription: longName is NULL");
        _longName = longName;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ - name: %@", NSStringFromClass([self class]), self.name];
}

@end

#pragma mark - VLCRendererDiscoverer

@implementation VLCRendererDiscoverer

- (nullable instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        NSAssert(name, @"VLCRendererDiscoverer: name is NULL");
        _name = name;
        _rendererDiscoverer = libvlc_renderer_discoverer_new([VLCLibrary sharedLibrary].instance, [name UTF8String]);

        if (!_rendererDiscoverer) {
            NSAssert(_rendererDiscoverer, @"Failed to create renderer with name %@", name);
            return nil;
        }

        _rendererItems = [[NSMutableArray alloc] init];
        libvlc_event_manager_t *p_em = libvlc_renderer_discoverer_event_manager(_rendererDiscoverer);
        _eventsHandler = [VLCEventsHandler handlerWithObject:self configuration:[VLCLibrary sharedEventsConfiguration]];
        if (p_em) {
            libvlc_event_attach(p_em, libvlc_RendererDiscovererItemAdded,
                                HandleRendererDiscovererItemAdded, (__bridge void *)(_eventsHandler));
            libvlc_event_attach(p_em, libvlc_RendererDiscovererItemDeleted,
                                HandleRendererDiscovererItemDeleted, (__bridge void *)(_eventsHandler));
        }
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ - name: %@ number of renderers: %lu", NSStringFromClass([self class]), self.name, _rendererItems.count];
}

- (BOOL)start
{
    return libvlc_renderer_discoverer_start(_rendererDiscoverer) == 0;
}

- (void)stop
{
    libvlc_renderer_discoverer_stop(_rendererDiscoverer);
}

- (void)dealloc
{
    libvlc_event_manager_t *p_em = libvlc_renderer_discoverer_event_manager(_rendererDiscoverer);

    if (p_em) {
        libvlc_event_detach(p_em, libvlc_RendererDiscovererItemAdded,
                            HandleRendererDiscovererItemAdded, (__bridge void *)(_eventsHandler));
        libvlc_event_detach(p_em, libvlc_RendererDiscovererItemDeleted,
                            HandleRendererDiscovererItemDeleted, (__bridge void *)(_eventsHandler));
    }

    if (_rendererDiscoverer) {
        libvlc_renderer_discoverer_release(_rendererDiscoverer);
    }
}

+ (nullable NSArray<VLCRendererDiscovererDescription *> *)list
{
    size_t i_nb_services = 0;
    libvlc_rd_description_t **pp_services = NULL;

    i_nb_services = libvlc_renderer_discoverer_list_get([VLCLibrary sharedLibrary].instance, &pp_services);

    if (i_nb_services == 0) {
        return NULL;
    }

    NSMutableArray *list = [[NSMutableArray alloc] init];

    for (size_t i = 0; i < i_nb_services; ++i) {
        [list addObject:[[VLCRendererDiscovererDescription alloc] initWithName:[NSString stringWithUTF8String:pp_services[i]->psz_name]
                                                                      longName:[NSString stringWithUTF8String:pp_services[i]->psz_longname]]];
    }

    if (pp_services) {
        libvlc_renderer_discoverer_list_release(pp_services, i_nb_services);
    }
    return [list copy];
}

- (nullable VLCRendererItem *)discoveredItemsContainItem:(VLCRendererItem *)item
{
    for (VLCRendererItem *rendererItem in _rendererItems) {
        BOOL hasSameName = [rendererItem.name isEqualToString:item.name];
        BOOL hasSameType = [rendererItem.type isEqualToString:item.type];

        if (hasSameName && hasSameType) {
            return rendererItem;
        }
    }
    return nil;
}

- (NSArray<VLCRendererItem *> *)renderers
{
    return [_rendererItems copy];
}

#pragma mark - Handling libvlc event callbacks

- (void)itemAdded:(VLCRendererItem *)item
{
    VLCRendererItem *rendererItem = [self discoveredItemsContainItem:item];

    if (!rendererItem) {
        [_rendererItems addObject:item];
        [_delegate rendererDiscovererItemAdded:self item:item];
    }
}

- (void)itemDeleted:(VLCRendererItem *)item
{
    VLCRendererItem *rendererItem = [self discoveredItemsContainItem:item];

    if (rendererItem) {
        [_rendererItems removeObject:rendererItem];
        [_delegate rendererDiscovererItemDeleted:self item:rendererItem];
    }
}

@end
