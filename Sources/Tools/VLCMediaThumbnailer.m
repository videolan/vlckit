/*****************************************************************************
 * VLCKit: VLCMediaThumbnailer
 *****************************************************************************
 * Copyright (C) 2010-2026 Pierre d'Herbemont and VideoLAN
 *
 * Authors: Pierre d'Herbemont
 *          Felix Paul Kühne <fkuehne # videolan.org
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

#import <vlc/vlc.h>

#import <VLCMediaThumbnailer.h>
#import <VLCLibVLCBridging.h>
#import <VLCTime.h>
#import <VLCLibrary.h>
#import <VLCEventsHandler.h>

@interface VLCMediaThumbnailer ()
{
    id<VLCMediaThumbnailerDelegate> __weak _thumbnailingDelegate;
    VLCMedia *_media;
    CGImageRef _thumbnail;
    CGFloat _thumbnailHeight, _thumbnailWidth;
    float _snapshotPosition;
    VLCTime *_snapshotTime;
    BOOL _hardwareDecodingEnabled, _preciseSeek, _cropsToFit;
    VLCLibrary *_library;
    libvlc_parser_t *_parser;
    libvlc_parser_task *_task;
    BOOL _cancelled;
    VLCEventsHandler *_eventsHandler;
}

- (void)handleThumbnailPicture:(nullable libvlc_picture_t *)picture;
@end

static const unsigned int kDefaultImageWidth = 320;
static const unsigned int kDefaultImageHeight = 240;
static const float kSnapshotPosition = 0.3;

static void thumbnailPictureReleaseCallback(void *info, const void *data, size_t size)
{
    libvlc_picture_release((libvlc_picture_t *)info);
}

/* Builds a CGImage referencing the picture's buffer without copying it. Consumes
 * one reference of `picture`: it is released when the returned CGImage is freed,
 * or immediately if the image can't be created. */
static CGImageRef VLCThumbnailCGImageCreate(libvlc_picture_t *picture) CF_RETURNS_RETAINED
{
    const libvlc_picture_type_t type = libvlc_picture_type(picture);
    const unsigned int width = libvlc_picture_get_width(picture);
    const unsigned int height = libvlc_picture_get_height(picture);
    const unsigned int stride = libvlc_picture_get_stride(picture);
    size_t size = 0;
    const unsigned char *buffer = libvlc_picture_get_buffer(picture, &size);

    if ((type != libvlc_picture_Rgba && type != libvlc_picture_Argb)
        || buffer == NULL || width == 0 || height == 0) {
        libvlc_picture_release(picture);
        return NULL;
    }

    CGDataProviderRef provider = CGDataProviderCreateWithData(picture, buffer, size, thumbnailPictureReleaseCallback);
    if (provider == NULL) {
        libvlc_picture_release(picture);
        return NULL;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef image = CGImageCreate(width, height, 8, 32, stride, colorSpace,
                                     kCGBitmapByteOrderDefault | kCGImageAlphaNoneSkipLast,
                                     provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);

    return image;
}

static void thumbnailer_on_ended(void *opaque, libvlc_parser_task *task, libvlc_picture_t *picture)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        libvlc_picture_t *retained = picture ? libvlc_picture_retain(picture) : NULL;
        [eventsHandler handleEvent:^(id object) {
            VLCMediaThumbnailer *thumbnailer = (VLCMediaThumbnailer *)object;
            [thumbnailer handleThumbnailPicture:retained];
        }];
    }
}

static const struct libvlc_thumbnailer_cbs thumbnailer_cbs = {
    .version = 0,
    .on_ended = thumbnailer_on_ended,
};

@implementation VLCMediaThumbnailer
@synthesize media=_media;
@synthesize delegate=_thumbnailingDelegate;
@synthesize thumbnail=_thumbnail;
@synthesize thumbnailWidth=_thumbnailWidth;
@synthesize thumbnailHeight=_thumbnailHeight;
@synthesize snapshotPosition=_snapshotPosition;
@synthesize snapshotTime=_snapshotTime;
@synthesize hardwareDecodingEnabled=_hardwareDecodingEnabled;
@synthesize preciseSeek=_preciseSeek;
@synthesize cropsToFit=_cropsToFit;

+ (VLCMediaThumbnailer *)thumbnailerWithMedia:(VLCMedia *)media andDelegate:(id<VLCMediaThumbnailerDelegate>)delegate
{
    return [self thumbnailerWithMedia:media delegate:delegate andVLCLibrary:nil];
}

+ (VLCMediaThumbnailer *)thumbnailerWithMedia:(VLCMedia *)media delegate:(id<VLCMediaThumbnailerDelegate>)delegate andVLCLibrary:(nullable VLCLibrary *)library
{
    VLCMediaThumbnailer *obj = [[self class] new];
    obj.media = media;
    obj.delegate = delegate;
    [obj setVLCLibrary: library ?: [VLCLibrary sharedLibrary]];
    return obj;
}

- (void)dealloc
{
    if (_parser != NULL)
        libvlc_parser_destroy(_parser);
    if (_task != NULL)
        libvlc_parser_task_release(_task);
    if (_thumbnail)
        CGImageRelease(_thumbnail);
}

- (void)setVLCLibrary:(VLCLibrary *)library
{
    _library = library;
}

- (void)fetchThumbnail
{
    NSAssert(_parser == NULL, @"We are already fetching a thumbnail");

    libvlc_media_t *p_media = [_media libVLCMediaDescriptor];
    if (p_media == NULL)
        return;

    const unsigned int imageWidth = _thumbnailWidth > 0 ? (unsigned int)_thumbnailWidth : kDefaultImageWidth;
    const unsigned int imageHeight = _thumbnailHeight > 0 ? (unsigned int)_thumbnailHeight : kDefaultImageHeight;

    // remote media may take considerably longer to open than a local file
    const BOOL isLocal = [_media.url.scheme isEqualToString:@"file"];
    const struct libvlc_parser_cfg cfg = {
        .version = 0,
        .max_parser_threads = 0,
        .max_thumbnailer_threads = 0,
        .timeout = (libvlc_time_t)(isLocal ? 10 : 45) * 1000000, // microseconds
    };
    _parser = libvlc_parser_new(_library.instance, &cfg);
    if (_parser == NULL)
        return;

    _eventsHandler = [VLCEventsHandler handlerWithObject:self configuration:[VLCLibrary sharedEventsConfiguration]];

    libvlc_thumbnailer_request_t request = { 0 };
    request.version = 0;
    request.media = p_media;
    request.width = imageWidth;
    request.height = imageHeight;
    request.crop = _cropsToFit;
    request.type = libvlc_picture_Rgba;
    request.hw_dec = _hardwareDecodingEnabled;
    request.seek.speed = _preciseSeek ? libvlc_media_thumbnail_seek_precise : libvlc_media_thumbnail_seek_fast;
    if (_snapshotTime != nil) {
        request.seek.type = libvlc_thumbnailer_seek_time;
        request.seek.value.time = (libvlc_time_t)[[_snapshotTime value] longLongValue] * 1000; // ms -> us
    } else {
        request.seek.type = libvlc_thumbnailer_seek_pos;
        request.seek.value.pos = _snapshotPosition > 0 ? _snapshotPosition : kSnapshotPosition;
    }

    _task = libvlc_parser_task_new_thumbnail(_parser, &request, &thumbnailer_cbs, (__bridge void *)_eventsHandler);
    if (_task == NULL) {
        [_thumbnailingDelegate mediaThumbnailerDidTimeOut:self];
        return;
    }

    if (libvlc_parser_submit(_parser, _task) != 0) {
        libvlc_parser_task_release(_task);
        _task = NULL;
        [_thumbnailingDelegate mediaThumbnailerDidTimeOut:self];
    }
}

- (void)cancel
{
    @synchronized (self) {
        _cancelled = YES;
        if (_parser != NULL && _task != NULL)
            libvlc_parser_cancel_request(_parser, _task);
    }
}

- (void)handleThumbnailPicture:(nullable libvlc_picture_t *)picture
{
    BOOL cancelled;
    @synchronized (self) {
        cancelled = _cancelled;
    }
    if (cancelled) {
        if (picture != NULL)
            libvlc_picture_release(picture);
        return;
    }

    CGImageRef image = picture ? VLCThumbnailCGImageCreate(picture) : NULL;
    if (image == NULL) {
        [_thumbnailingDelegate mediaThumbnailerDidTimeOut:self];
        return;
    }

    if (_thumbnail)
        CGImageRelease(_thumbnail);
    _thumbnail = image;
    _thumbnailWidth = CGImageGetWidth(image);
    _thumbnailHeight = CGImageGetHeight(image);

    [_thumbnailingDelegate mediaThumbnailer:self didFinishThumbnail:_thumbnail];
}

@end
