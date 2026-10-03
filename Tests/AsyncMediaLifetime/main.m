// SPDX-License-Identifier: LGPL-2.1-or-later
#import <Foundation/Foundation.h>
#import "VLCEventsHandler.h"
#import "VLCEventsConfiguration.h"
#include <assert.h>

typedef struct {
    unsigned refs;
    void *userData;
} libvlc_media_t;
typedef struct { uint8_t bytes[4]; } libvlc_picture_t;
typedef struct { libvlc_picture_t picture; } libvlc_picture_list_t;

static BOOL insideCallback;
static unsigned liveDescriptors, liveWrappers, deliveries;
static libvlc_media_t *descriptorNew(void) {
    libvlc_media_t *md = calloc(1, sizeof(*md));
    md->refs = 1;
    liveDescriptors++;
    return md;
}
static void descriptorRelease(libvlc_media_t *md) {
    if (--md->refs == 0) { liveDescriptors--; free(md); }
}
static void *libvlc_media_get_user_data(libvlc_media_t *md) {
    assert(insideCallback && "Raw descriptor looked up after callback return");
    return md->userData;
}
static size_t libvlc_picture_list_count(libvlc_picture_list_t *list) { return 1; }
static libvlc_picture_t *libvlc_picture_list_at(libvlc_picture_list_t *list, size_t index) {
    assert(insideCallback);
    return &list->picture;
}
static const uint8_t *libvlc_picture_get_buffer(libvlc_picture_t *picture, size_t *size) {
    assert(insideCallback);
    *size = sizeof(picture->bytes);
    return picture->bytes;
}

@interface VLCMedia : NSObject {
    libvlc_media_t *_md;
}
+ (instancetype)mediaWithLibVLCMediaDescriptor:(libvlc_media_t *)md;
- (void)metaChanged;
- (void)subitemsChanged;
- (void)artworkAttachmentReceived:(NSData *)data;
@end

@implementation VLCMedia
+ (instancetype)mediaWithLibVLCMediaDescriptor:(libvlc_media_t *)md {
    assert(insideCallback);
    VLCMedia *media = [self new];
    media->_md = md;
    md->refs++;
    md->userData = (__bridge void *)media;
    liveWrappers++;
    return media;
}
- (void)dealloc {
    assert(_md->userData == (__bridge void *)self);
    _md->userData = NULL;
    descriptorRelease(_md);
    liveWrappers--;
}
- (void)metaChanged {
    assert(!insideCallback && [NSThread isMainThread]);
    assert(_md->refs > 0);
    deliveries++;
}
- (void)subitemsChanged { [self metaChanged]; }
- (void)artworkAttachmentReceived:(NSData *)data {
    const uint8_t expected[] = {1, 2, 3, 4};
    assert([data isEqualToData:[NSData dataWithBytes:expected length:4]]);
    [self metaChanged];
}
@end

@interface VLCMediaPlayer : NSObject
- (void)mediaPlayerMediaChanged:(VLCMedia *)media;
@end
@implementation VLCMediaPlayer
- (void)mediaPlayerMediaChanged:(VLCMedia *)media {
    assert(!insideCallback && [NSThread isMainThread]);
    if (media) [media metaChanged]; else deliveries++;
}
@end

#include "Callbacks.inc"

static void drainMainQueue(void) {
    __block BOOL drained = NO;
    dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!drained && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode
                           beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    assert(drained);
}

static void runCase(unsigned kind, BOOL existingWrapper, BOOL dropped, BOOL nullMedia) {
    unsigned before = deliveries;
    @autoreleasepool {
        VLCMediaPlayer *player = [VLCMediaPlayer new];
        VLCEventsHandler *handler = [VLCEventsHandler handlerWithObject:player
                                          configuration:[VLCEventsLegacyConfiguration new]];
        if (dropped) { player = nil; assert(handler.object == nil); }
        insideCallback = YES;
        libvlc_media_t *md = nullMedia ? NULL : descriptorNew();
        VLCMedia *media = existingWrapper && md ? [VLCMedia mediaWithLibVLCMediaDescriptor:md] : nil;
        __weak VLCMedia *weakMedia = media;
        libvlc_picture_list_t pictures = {{{1, 2, 3, 4}}};
        void *opaque = (__bridge void *)handler;
        switch (kind) {
            case 0: HandleMediaPlayerMediaChanged(opaque, md); break;
            case 1: HandleMediaPlayerMediaMetaChanged(opaque, md); break;
            case 2: HandleMediaPlayerMediaSubItemsChanged(opaque, md); break;
            case 3: HandleMediaPlayerMediaAttachmentsAdded(opaque, md, &pictures); break;
        }
        insideCallback = NO;
        assert(deliveries == before); // Legacy dispatch must remain asynchronous.
        memset(&pictures, 0, sizeof(pictures));
        media = nil;
        if (md) descriptorRelease(md); // Stop/replace before the queue drains.
        player = nil;
        handler = nil;
        if (existingWrapper && !dropped && !nullMedia) assert(weakMedia != nil);
    }
    @autoreleasepool { drainMainQueue(); }
    assert(deliveries == before + (!dropped && (!nullMedia || kind == 0)));
    assert(liveWrappers == 0 && liveDescriptors == 0); // Includes dropped events.
}

int main(void) {
    @autoreleasepool {
        const unsigned kinds[] = {1, 0, 2, 3}; // Reproduce metadata first.
        for (unsigned iteration = 0; iteration < 100; iteration++)
            for (unsigned kind = 0; kind < 4; kind++)
                for (unsigned existing = 0; existing < 2; existing++)
                    for (unsigned dropped = 0; dropped < 2; dropped++)
                        for (unsigned nullMedia = 0; nullMedia < 2; nullMedia++)
                            runCase(kinds[kind], existing, dropped, nullMedia);
        puts("PASS: 3,200 async lifetime cases; no late descriptor lookup or leaked media.");
    }
}
