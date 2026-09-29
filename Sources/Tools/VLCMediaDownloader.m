/*****************************************************************************
 * VLCMediaDownloader.m
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org
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

#import "VLCMediaDownloader.h"
#import "VLCLibrary.h"
#import "VLCMedia.h"
#import "VLCMediaList.h"
#import "VLCLibVLCBridging.h"
#include <vlc/vlc.h>

const NSInteger VLCMediaDownloadConsumedError  = -1;
const NSInteger VLCMediaDownloadConsumedCancel = -2;

static VLCMediaDownloadStatus VLCMediaDownloadStatusFromLibVLC(libvlc_downloader_status_t status)
{
    switch (status) {
        case libvlc_downloader_status_pending:   return VLCMediaDownloadStatusPending;
        case libvlc_downloader_status_running:   return VLCMediaDownloadStatusRunning;
        case libvlc_downloader_status_paused:    return VLCMediaDownloadStatusPaused;
        case libvlc_downloader_status_finished:  return VLCMediaDownloadStatusFinished;
        case libvlc_downloader_status_cancelled: return VLCMediaDownloadStatusCancelled;
        case libvlc_downloader_status_error:     return VLCMediaDownloadStatusError;
    }
    return VLCMediaDownloadStatusError;
}

static BOOL VLCMediaDownloadStatusIsTerminal(VLCMediaDownloadStatus status)
{
    return status == VLCMediaDownloadStatusFinished
        || status == VLCMediaDownloadStatusCancelled
        || status == VLCMediaDownloadStatusError;
}

@interface VLCMediaDownloadTask ()
{
    libvlc_downloader_t *_libvlcDownloader;
    libvlc_downloader_task *_libvlcTask;
    BOOL _finished;
}
@property (nonatomic, readwrite) VLCMedia *media;
@property (nonatomic, readwrite) VLCMediaDownloadStatus status;
@property (nonatomic, weak) id<VLCMediaDownloaderDelegate> delegate;
@property (nonatomic, weak) VLCMediaDownloader *owner;

- (instancetype)initWithMedia:(VLCMedia *)media
                     delegate:(id<VLCMediaDownloaderDelegate>)delegate
                        owner:(VLCMediaDownloader *)owner
             libvlcDownloader:(libvlc_downloader_t *)libvlcDownloader;
- (void)setLibVLCTask:(libvlc_downloader_task *)task;

- (NSInteger)handleBuffer:(const uint8_t *)buf length:(size_t)len position:(uint64_t)position total:(uint64_t)total;
- (void)handleStatus:(libvlc_downloader_status_t)status;
- (void)handleSubitems:(libvlc_media_list_t *)subitems;
- (void)handleSlaves:(libvlc_media_slave_t **)slaves count:(size_t)count;
@end

@interface VLCMediaDownloader ()
{
    libvlc_downloader_t *_downloader;
    NSMutableSet<VLCMediaDownloadTask *> *_activeTasks;
}
- (void)removeActiveTask:(VLCMediaDownloadTask *)task;
@end

static ptrdiff_t downloader_on_buffer(void *opaque, libvlc_downloader_task *task,
                                      const uint8_t *buf, size_t len,
                                      uint64_t position, uint64_t total)
{
    @autoreleasepool {
        VLCMediaDownloadTask *t = (__bridge VLCMediaDownloadTask *)opaque;
        return (ptrdiff_t)[t handleBuffer:buf length:len position:position total:total];
    }
}

static void downloader_on_state_update(void *opaque, libvlc_downloader_task *task,
                                       libvlc_downloader_status_t status)
{
    @autoreleasepool {
        VLCMediaDownloadTask *t = (__bridge VLCMediaDownloadTask *)opaque;
        [t handleStatus:status];
    }
}

static void downloader_on_subitems(void *opaque, libvlc_downloader_task *task,
                                   libvlc_media_list_t *subitems)
{
    @autoreleasepool {
        VLCMediaDownloadTask *t = (__bridge VLCMediaDownloadTask *)opaque;
        [t handleSubitems:subitems];
    }
}

static void downloader_on_slaves(void *opaque, libvlc_downloader_task *task,
                                 libvlc_media_slave_t **slaves, size_t count)
{
    @autoreleasepool {
        VLCMediaDownloadTask *t = (__bridge VLCMediaDownloadTask *)opaque;
        [t handleSlaves:slaves count:count];
    }
}

static const struct libvlc_downloader_cbs downloader_cbs = {
    .version = 0,
    .on_buffer = downloader_on_buffer,
    .on_state_update = downloader_on_state_update,
    .on_subitems = downloader_on_subitems,
    .on_slaves = downloader_on_slaves,
};

@implementation VLCMediaDownloadTask

- (instancetype)initWithMedia:(VLCMedia *)media
                     delegate:(id<VLCMediaDownloaderDelegate>)delegate
                        owner:(VLCMediaDownloader *)owner
             libvlcDownloader:(libvlc_downloader_t *)libvlcDownloader
{
    self = [super init];
    if (self) {
        _media = media;
        _delegate = delegate;
        _owner = owner;
        _libvlcDownloader = libvlcDownloader;
        _status = VLCMediaDownloadStatusPending;
    }
    return self;
}

- (void)setLibVLCTask:(libvlc_downloader_task *)task
{
    @synchronized (self) {
        if (_finished)
            libvlc_downloader_task_release(task);
        else
            _libvlcTask = task;
    }
}

- (NSInteger)handleBuffer:(const uint8_t *)buf length:(size_t)len position:(uint64_t)position total:(uint64_t)total
{
    id<VLCMediaDownloaderDelegate> delegate = self.delegate;
    if (delegate == nil)
        return VLCMediaDownloadConsumedCancel;

    NSData *data = [NSData dataWithBytesNoCopy:(void *)buf length:len freeWhenDone:NO];
    return [delegate mediaDownloadTask:self didReceiveData:data position:position total:total];
}

- (void)handleStatus:(libvlc_downloader_status_t)status
{
    VLCMediaDownloadStatus mappedStatus = VLCMediaDownloadStatusFromLibVLC(status);
    self.status = mappedStatus;

    id<VLCMediaDownloaderDelegate> delegate = self.delegate;
    if (delegate != nil)
        [delegate mediaDownloadTask:self didUpdateStatus:mappedStatus];

    if (VLCMediaDownloadStatusIsTerminal(mappedStatus)) {
        @synchronized (self) {
            _finished = YES;
            if (_libvlcTask != NULL) {
                libvlc_downloader_task_release(_libvlcTask);
                _libvlcTask = NULL;
            }
        }
        [self.owner removeActiveTask:self];
    }
}

- (void)handleSubitems:(libvlc_media_list_t *)subitems
{
    id<VLCMediaDownloaderDelegate> delegate = self.delegate;
    if (![delegate respondsToSelector:@selector(mediaDownloadTask:didReceiveSubitems:)])
        return;

    VLCMediaList *list = [VLCMediaList mediaListWithLibVLCMediaList:subitems];
    [delegate mediaDownloadTask:self didReceiveSubitems:list];
}

- (void)handleSlaves:(libvlc_media_slave_t **)slaves count:(size_t)count
{
    id<VLCMediaDownloaderDelegate> delegate = self.delegate;
    if (![delegate respondsToSelector:@selector(mediaDownloadTask:didReceiveSlaves:)])
        return;

    NSMutableArray<VLCMediaSlave *> *array = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; i++) {
        VLCMediaSlave *slave = [VLCMediaSlave mediaSlaveWithLibVLCSlave:slaves[i]];
        if (slave != nil)
            [array addObject:slave];
    }
    [delegate mediaDownloadTask:self didReceiveSlaves:array];
}

- (void)cancel
{
    @synchronized (self) {
        if (_libvlcTask != NULL && _libvlcDownloader != NULL)
            libvlc_downloader_cancel(_libvlcDownloader, _libvlcTask);
    }
}

- (BOOL)isPaused
{
    return self.status == VLCMediaDownloadStatusPaused;
}

- (void)setPaused:(BOOL)paused
{
    @synchronized (self) {
        if (_libvlcTask != NULL && _libvlcDownloader != NULL)
            libvlc_downloader_set_pause(_libvlcDownloader, _libvlcTask, paused);
    }
}

@end

@implementation VLCMediaDownloader

- (instancetype)init
{
    return [self initWithLibrary:[VLCLibrary sharedLibrary]];
}

- (instancetype)initWithLibrary:(VLCLibrary *)library
{
    self = [super init];
    if (self) {
        const struct libvlc_downloader_cfg cfg = {
            .version = 0,
            .max_parser_threads = 0,
        };
        _downloader = libvlc_downloader_new(library.instance, &cfg);
        _activeTasks = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc
{
    if (_downloader != NULL)
        libvlc_downloader_destroy(_downloader);
}

- (VLCMediaDownloadTask *)downloadMedia:(VLCMedia *)media
                               delegate:(id<VLCMediaDownloaderDelegate>)delegate
{
    if (media == nil || delegate == nil || _downloader == NULL)
        return nil;

    libvlc_media_t *p_media = [media libVLCMediaDescriptor];
    if (p_media == NULL)
        return nil;

    VLCMediaDownloadTask *task = [[VLCMediaDownloadTask alloc] initWithMedia:media
                                                                   delegate:delegate
                                                                      owner:self
                                                           libvlcDownloader:_downloader];

    @synchronized (self) {
        [_activeTasks addObject:task];
    }

    const libvlc_downloader_request_t request = {
        .version = 0,
        .media = p_media,
    };

    libvlc_downloader_task *p_task = libvlc_downloader_task_new(_downloader, &request,
                                                                &downloader_cbs, (__bridge void *)task);
    if (p_task == NULL || libvlc_downloader_submit(_downloader, p_task) != 0) {
        if (p_task != NULL)
            libvlc_downloader_task_release(p_task);
        @synchronized (self) {
            [_activeTasks removeObject:task];
        }
        return nil;
    }

    [task setLibVLCTask:p_task];
    return task;
}

- (void)cancelAll
{
    if (_downloader != NULL)
        libvlc_downloader_cancel(_downloader, NULL);
}

- (void)removeActiveTask:(VLCMediaDownloadTask *)task
{
    @synchronized (self) {
        [_activeTasks removeObject:task];
    }
}

@end
