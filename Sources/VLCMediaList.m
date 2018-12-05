/*****************************************************************************
 * VLCMediaList.m: VLCKit.framework VLCMediaList implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007 VLC authors and VideoLAN
 * Copyright (C) 2009, 2013, 2017 Felix Paul Kühne
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

#import "VLCMediaList.h"
#import "VLCLibrary.h"
#import "VLCEventManager.h"
#import "VLCLibVLCBridging.h"
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc/vlc.h>
#include <vlc/libvlc.h>

/* Notification Messages */
NSString *const VLCMediaListItemAdded        = @"VLCMediaListItemAdded";
NSString *const VLCMediaListItemDeleted      = @"VLCMediaListItemDeleted";

// TODO: Documentation
@interface VLCMediaList (Private)

/* Initializers */
- (void)initInternalMediaList;

/* Libvlc event bridges */
- (void)mediaListItemAdded:(NSArray *)args;
- (void)mediaListItemRemoved:(NSNumber *)index;
@end

/* libvlc event callback */
static void HandleMediaListItemAdded(const libvlc_event_t * event, void * user_data)
{
    @autoreleasepool {
        id self = (__bridge id)(user_data);
        [[VLCEventManager sharedManager] callOnMainThreadObject:self
                                                     withMethod:@selector(mediaListItemAdded:)
                                           withArgumentAsObject:@[@{@"media": [VLCMedia mediaWithLibVLCMediaDescriptor:event->u.media_list_item_added.item],
                                                              @"index": @(event->u.media_list_item_added.index)}]];
    }
}

static void HandleMediaListItemDeleted( const libvlc_event_t * event, void * user_data)
{
    @autoreleasepool {
        id self = (__bridge id)(user_data);
        [[VLCEventManager sharedManager] callOnMainThreadObject:self
                                                     withMethod:@selector(mediaListItemRemoved:)
                                           withArgumentAsObject:@[@{@"media": [VLCMedia mediaWithLibVLCMediaDescriptor:event->u.media_list_item_deleted.item],
                                                                    @"index": @(event->u.media_list_item_deleted.index)}]];
    }
}

@interface VLCMediaList()
{
    void * p_mlist;                                 ///< Internal instance of media list
    id <VLCMediaListDelegate,NSObject> __weak delegate;    ///< Delegate object
    /* We need that private copy because of Cocoa Bindings, that need to be working on first thread */
    NSMutableArray *_mediaObjects;                   ///< Private copy of media objects.
    dispatch_queue_t _serialMediaObjectsQueue;      ///< Queue for accessing and modifying the mediaobjects
}
@end

@implementation VLCMediaList
- (instancetype)init
{
    if (self = [super init]) {
        // Create a new libvlc media list instance
        p_mlist = libvlc_media_list_new([VLCLibrary sharedLibrary].instance);

        // Initialize internals to defaults
        _mediaObjects = [[NSMutableArray alloc] init];

        dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                                     QOS_CLASS_USER_INITIATED,
                                                                                     0);

        _serialMediaObjectsQueue = dispatch_queue_create("org.videolan.serialMediaObjectsQueue", qosAttribute);
        [self initInternalMediaList];
    }

    return self;
}

- (instancetype)initWithArray:(NSArray *)array
{
    if (self = [self init]) {
        /* do something useful with the provided array */
        NSUInteger count = [array count];
        for (NSUInteger x = 0; x < count; x++)
            [self addMedia:array[x]];
    }

    return self;
}

- (void)dealloc
{
    libvlc_event_manager_t *em = libvlc_media_list_event_manager(p_mlist);
    if (em) {
        libvlc_event_detach(em, libvlc_MediaListItemDeleted, HandleMediaListItemDeleted, (__bridge void *)(self));
        libvlc_event_detach(em, libvlc_MediaListItemAdded,   HandleMediaListItemAdded,   (__bridge void *)(self));
    }
    [[VLCEventManager sharedManager] cancelCallToObject:self];

    // Release allocated memory
    delegate = nil;

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
    // Add the media object to our cache
    dispatch_sync(_serialMediaObjectsQueue, ^{
        [_mediaObjects insertObject:media atIndex:index];
    });

    // Add it to libvlc's medialist
    libvlc_media_list_insert_media(p_mlist, [media libVLCMediaDescriptor], (int)index);
}

- (BOOL)removeMediaAtIndex:(NSUInteger)index
{
    __block BOOL ok = YES;
    
    dispatch_sync(_serialMediaObjectsQueue, ^{
        // Remove from cached Media
        if (index >= [_mediaObjects count]) {
            ok = NO;
            return;
        }
        [_mediaObjects removeObjectAtIndex:index];
    });

    // Remove from libvlc's medialist
    libvlc_media_list_remove_index(p_mlist, (int)index);
    return ok;
}

- (VLCMedia *)mediaAtIndex:(NSUInteger)index
{
    __block VLCMedia *media;
    dispatch_sync(_serialMediaObjectsQueue, ^{
        media = index >= [_mediaObjects count] ? nil : [_mediaObjects objectAtIndex:index];
    });
    return media;
}

- (NSUInteger)indexOfMedia:(VLCMedia *)media
{
    return [_mediaObjects indexOfObject:media];
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

@synthesize delegate;

- (BOOL)isReadOnly
{
    return libvlc_media_list_is_readonly( p_mlist );
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
        [self initInternalMediaList];
        libvlc_media_list_unlock(p_mlist);
    }
    return self;
}

- (void *)libVLCMediaList
{
    return p_mlist;
}
@end

@implementation VLCMediaList (Private)
- (void)initInternalMediaList
{
    // Add event callbacks
    libvlc_event_manager_t *em = libvlc_media_list_event_manager(p_mlist);
    if (!em)
        return;

    /* We need the caller to wait until this block is done.
     * The initialized object shall not be returned until the event attachments are done. */
    dispatch_sync(_serialMediaObjectsQueue,^{
        libvlc_event_attach( em, libvlc_MediaListItemAdded,   HandleMediaListItemAdded,   (__bridge void *)(self));
        libvlc_event_attach( em, libvlc_MediaListItemDeleted, HandleMediaListItemDeleted, (__bridge void *)(self));
    });
}

- (void)mediaListItemAdded:(NSArray *)arrayOfArgs
{
    /* We hope to receive index in a nide range, that could change one day */
    NSInteger start = [arrayOfArgs[0][@"index"] intValue];
    NSInteger end = [arrayOfArgs[[arrayOfArgs count]-1][@"index"] intValue];
    NSRange range = NSMakeRange(start, end-start);

    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range] forKey:@"media"];
    for (NSDictionary *args in arrayOfArgs) {
        NSInteger index = [args[@"index"] intValue];
        VLCMedia *tempMedia = args[@"media"];
        __block VLCMedia *foundMedia;
        //we have two instances of VLCMedia. One from the event and the one we added to _mediaObjects, hence check them to avoid duplication
        dispatch_sync(_serialMediaObjectsQueue, ^{
            for (VLCMedia *media in _mediaObjects) {
                if ([tempMedia.url isEqual:media.url]){
                    foundMedia = media;
                    break;
                }
            }
        });

        if (!foundMedia) {
            // In case we found Media on the network we don't have a cached copy yet
            foundMedia = tempMedia;
            dispatch_sync(_serialMediaObjectsQueue, ^{
                index >= [_mediaObjects count] ? [_mediaObjects addObject:foundMedia] : [_mediaObjects insertObject:foundMedia atIndex:index];
            });
        }
        if (delegate && [delegate respondsToSelector:@selector(mediaList:mediaAdded:atIndex:)])
            [delegate mediaList:self mediaAdded:foundMedia atIndex:index];
    }
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range] forKey:@"media"];
}

- (void)mediaListItemRemoved:(NSArray *)arguments
{
    NSNumber *index = arguments.firstObject[@"index"];
    VLCMedia *deleted = arguments.firstObject[@"media"];
    
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:[index intValue]] forKey:@"media"];
    dispatch_sync(_serialMediaObjectsQueue, ^{
        if ([_mediaObjects containsObject:deleted]) {
            [_mediaObjects removeObject:deleted];
        }
    });
    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:[index intValue]] forKey:@"media"];
    
    // Post the notification
    [[NSNotificationCenter defaultCenter] postNotificationName:VLCMediaListItemDeleted
                                                        object:self
                                                      userInfo:@{@"index": index}];

    // Let the delegate know that the item is being removed
    if (delegate && [delegate respondsToSelector:@selector(mediaList:mediaRemovedAtIndex:)])
        [delegate mediaList:self mediaRemovedAtIndex:[index intValue]];
}
@end
