/*****************************************************************************
 * VLCMediaList.m: VLCKit.framework VLCMediaList implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007 VLC authors and VideoLAN
 * Copyright (C) 2009, 2013, 2017, 2024 Felix Paul Kühne
 * Copyright (C) 2018 Carola Nitz
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *          Felix Paul Kühne <fkuehne # videolan.org>
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

#import <VLCMediaList.h>
#import <VLCMedia.h>
#import <VLCMediaMetaData.h>
#import <VLCLibrary.h>
#import <VLCLibVLCBridging.h>
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc/vlc.h>
#include <vlc/libvlc.h>

@interface VLCMediaList()
{
    void * p_mlist;                                 ///< Internal instance of media list
    /* We need that private copy because of Cocoa Bindings, that need to be working on first thread */
    NSMutableArray<VLCMedia *> *_mediaObjects;                   ///< Private copy of media objects.
    dispatch_queue_t _serialMediaObjectsQueue;      ///< Queue for accessing and modifying the mediaobjects
    NSMapTable<id, NSNumber *> *_indexCache;                     ///< Lazy descriptor->index cache for -indexOfMedia:, invalidated on mutation
}
@end

@implementation VLCMediaList
- (instancetype)init
{
    if (self = [super init]) {
        // Create a new libvlc media list instance
        p_mlist = libvlc_media_list_new();

        // Initialize internals to defaults
        _mediaObjects = [[NSMutableArray alloc] init];

        dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                                     QOS_CLASS_USER_INITIATED,
                                                                                     0);

        _serialMediaObjectsQueue = dispatch_queue_create("org.videolan.serialMediaObjectsQueue", qosAttribute);
    }

    return self;
}

- (instancetype)initWithArray:(nullable NSArray<VLCMedia *> *)array
{
    if (self = [self init]) {
        /* do something useful with the provided array */
        [array enumerateObjectsUsingBlock:^(VLCMedia * _Nonnull media, NSUInteger idx, BOOL * _Nonnull stop) {
            [self addMedia: media];
        }];
    }

    return self;
}

- (void)dealloc
{
    libvlc_media_list_release( p_mlist );
}

- (NSString *)description
{
    NSMutableString * content = [NSMutableString string];
    for (NSInteger i = 0; i < [self count]; i++) {
        [content appendFormat:@"%@\n", [self mediaAtIndex: i]];
    }
    return [NSString stringWithFormat:@"<%@ %p> {\n%@}", [self class], self, content];
}

- (void)lock
{
    libvlc_media_list_lock( p_mlist );
}

- (void)unlock
{
    libvlc_media_list_unlock( p_mlist );
}

- (NSUInteger)addMedia:(VLCMedia *)media
{
    NSInteger index = [self count];
    [self insertMedia:media atIndex:index];
    return index;
}

- (void)insertMedia:(VLCMedia *)media atIndex: (NSUInteger)index
{
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"media"];

    // Add the media object to our cache
    dispatch_sync(_serialMediaObjectsQueue, ^{
        [_mediaObjects insertObject:media atIndex:index];
        _indexCache = nil;
    });

    // Add it to libvlc's medialist
    libvlc_media_list_insert_media(p_mlist, [media libVLCMediaDescriptor], (int)index);

    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexSet forKey:@"media"];
}

- (BOOL)removeMediaAtIndex:(NSUInteger)index
{
    __block BOOL ok = YES;
    dispatch_sync(_serialMediaObjectsQueue, ^{
        ok = index < [_mediaObjects count];
    });

    if (!ok)
        return NO;

    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"media"];

    dispatch_sync(_serialMediaObjectsQueue, ^{
        [_mediaObjects removeObjectAtIndex:index];
        _indexCache = nil;
    });

    libvlc_media_list_remove_index(p_mlist, (int)index);

    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexSet forKey:@"media"];
    return YES;
}

- (nullable VLCMedia *)mediaAtIndex:(NSUInteger)index
{
    __block VLCMedia *media;
    dispatch_sync(_serialMediaObjectsQueue, ^{
        media = index >= [_mediaObjects count] ? nil : [_mediaObjects objectAtIndex:index];
    });
    return media;
}

- (NSUInteger)indexOfMedia:(VLCMedia *)media
{
    libvlc_media_t *p_md = [media libVLCMediaDescriptor];
    if (p_md == NULL)
        return NSNotFound;

    __block NSUInteger result = NSNotFound;
    dispatch_sync(_serialMediaObjectsQueue, ^{
        if (_indexCache == nil) {
            _indexCache = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)
                                                valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality)];
            NSUInteger idx = 0;
            for (VLCMedia *cachedMedia in _mediaObjects) {
                libvlc_media_t *md = [cachedMedia libVLCMediaDescriptor];
                if (md != NULL && [_indexCache objectForKey:(__bridge id)(void *)md] == nil)
                    [_indexCache setObject:@(idx) forKey:(__bridge id)(void *)md];
                idx++;
            }
        }
        NSNumber *cachedIndex = [_indexCache objectForKey:(__bridge id)(void *)p_md];
        if (cachedIndex != nil)
            result = cachedIndex.unsignedIntegerValue;
    });
    return result;
}

static BOOL VLCMediaListStatValue(VLCMedia *media, VLCMediaFileStatType type, uint64_t *value)
{
    return [media fileStatValueForType:type value:value] == VLCMediaFileStatReturnTypeSuccess && *value > 0;
}

- (NSArray<VLCMedia *> *)mediaSortedByCriteria:(VLCMediaListSortCriteria)criteria ascending:(BOOL)ascending
{
    __block NSArray<VLCMedia *> *snapshot;
    dispatch_sync(_serialMediaObjectsQueue, ^{
        snapshot = [_mediaObjects copy];
    });

    if (criteria == VLCMediaListSortCriteriaDefault)
        return snapshot;

    // precompute each media's sort key once instead of re-fetching it on every
    // O(n log n) comparison; pointer-identity keys skip -hash/-isEqual on VLCMedia
    BOOL byName = (criteria == VLCMediaListSortCriteriaName);
    VLCMediaFileStatType statType = (criteria == VLCMediaListSortCriteriaSize) ? VLCMediaFileStatTypeSize : VLCMediaFileStatTypeMtime;

    NSMapTable<VLCMedia *, NSString *> *titles = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsObjectPointerPersonality
                                                                      valueOptions:NSPointerFunctionsStrongMemory];
    NSMapTable<VLCMedia *, NSNumber *> *stats = byName ? nil : [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsObjectPointerPersonality
                                                                                    valueOptions:NSPointerFunctionsStrongMemory];

    for (VLCMedia *media in snapshot) {
        [titles setObject:(media.metaData.title ?: @"") forKey:media];
        if (!byName) {
            uint64_t value = 0;
            if (VLCMediaListStatValue(media, statType, &value))
                [stats setObject:@(value) forKey:media];
        }
    }

    return [snapshot sortedArrayUsingComparator:^NSComparisonResult(VLCMedia *a, VLCMedia *b) {
        if (!byName) {
            NSNumber *valueA = [stats objectForKey:a], *valueB = [stats objectForKey:b];
            if ((valueA != nil) != (valueB != nil))
                return valueA ? NSOrderedAscending : NSOrderedDescending;
            if (valueA && ![valueA isEqualToNumber:valueB]) {
                NSComparisonResult result = [valueA compare:valueB];
                return ascending ? result : (NSComparisonResult)(-result);
            }
        }
        NSComparisonResult result = [[titles objectForKey:a] localizedCaseInsensitiveCompare:[titles objectForKey:b]];
        return ascending ? result : (NSComparisonResult)(-result);
    }];
}

/* KVC Compliance: For the @"media" key */
- (NSInteger)countOfMedia
{
    return [self count];
}

- (VLCMedia *)objectInMediaAtIndex:(NSUInteger)i
{
    return [self mediaAtIndex:i];
}

- (NSInteger)count
{
    __block NSInteger count;
    dispatch_sync(_serialMediaObjectsQueue, ^{
        count = [_mediaObjects count];
    });
    return count;
}

- (void)insertObject:(VLCMedia *)object inMediaAtIndex:(NSUInteger)i
{
    [self insertMedia:object atIndex:i];
}

- (BOOL)isReadOnly
{
    return libvlc_media_list_is_readonly( p_mlist );
}

- (BOOL)isEmpty
{
    return [self count] == 0;
}

@end

@implementation VLCMediaList (LibVLCBridging)
+ (id)mediaListWithLibVLCMediaList:(void *)p_new_mlist;
{
    return [[VLCMediaList alloc] initWithLibVLCMediaList:p_new_mlist];
}

- (id)initWithLibVLCMediaList:(void *)p_new_mlist;
{
    if (self = [super init]) {
        p_mlist = p_new_mlist;
        libvlc_media_list_retain( p_mlist );
        libvlc_media_list_lock( p_mlist );
        _mediaObjects = [[NSMutableArray alloc] initWithCapacity:libvlc_media_list_count(p_mlist)];
        _serialMediaObjectsQueue = dispatch_queue_create("org.videolan.serialMediaObjectsQueue", NULL);
        NSUInteger count = libvlc_media_list_count(p_mlist);
        for (int i = 0; i < count; i++) {
            libvlc_media_t * p_md = libvlc_media_list_item_at_index(p_mlist, i);
            dispatch_sync(_serialMediaObjectsQueue, ^{
                [_mediaObjects addObject:[VLCMedia mediaWithLibVLCMediaDescriptor:p_md]];
            });
            libvlc_media_release(p_md);
        }
        libvlc_media_list_unlock(p_mlist);
    }
    return self;
}

- (void *)libVLCMediaList
{
    return p_mlist;
}
@end
