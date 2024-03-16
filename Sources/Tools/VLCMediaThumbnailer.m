/*****************************************************************************
 * VLCKit: VLCMediaThumbnailer
 *****************************************************************************
 * Copyright (C) 2010-2012 Pierre d'Herbemont and VideoLAN
 *
 * Authors: Pierre d'Herbemont
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

@interface VLCMediaThumbnailer ()
{
    NSObject<VLCMediaThumbnailerDelegate>* __weak _thumbnailingDelegate;
    VLCMedia *_media;
    void *_mp;
    CGImageRef _thumbnail;
    void *_data;
    NSTimer *_parsingTimeoutTimer;
    NSTimer *_thumbnailingTimeoutTimer;

    CGFloat _thumbnailHeight,_thumbnailWidth;
    float _snapshotPosition;
    CGFloat _effectiveThumbnailHeight,_effectiveThumbnailWidth;
    int _numberOfReceivedFrames;
    BOOL _shouldRejectFrames;

    VLCLibrary * _library;
}

- (void)didFetchThumbnail;
- (void)notifyDelegate;
- (void)fetchThumbnail;
- (void)startFetchingThumbnail;

@property (readonly, assign, nonatomic) void *dataPointer;
@property (readonly, assign, nonatomic) BOOL shouldRejectFrames;
@end

static void *lock(void *opaque, void **pixels)
{
    VLCMediaThumbnailer *thumbnailer = (__bridge VLCMediaThumbnailer *)(opaque);

    *pixels = [thumbnailer dataPointer];
    assert(*pixels);
    return NULL;
}

static const size_t kDefaultImageWidth = 320;
static const size_t kDefaultImageHeight = 240;
static const float kSnapshotPosition = 0.3;
static const long long kStandardStartTime = 150000;

void unlock(void *opaque, void *picture, void *const *p_pixels)
{
    (void)picture;
    (void)p_pixels;
}

static void display(void *opaque, void *picture)
{
    VLCMediaThumbnailer *thumbnailer = (__bridge VLCMediaThumbnailer *)(opaque);
    assert(!picture);

    // We may already have a thumbnail if we are receiving picture after the first one.
    // Just ignore.
    if ([thumbnailer thumbnail] || [thumbnailer shouldRejectFrames])
        return;

    [thumbnailer performSelectorOnMainThread:@selector(didFetchThumbnail) withObject:nil waitUntilDone:YES];
}

@implementation VLCMediaThumbnailer
@synthesize media=_media;
@synthesize delegate=_thumbnailingDelegate;
@synthesize thumbnail=_thumbnail;
@synthesize dataPointer=_data;
@synthesize thumbnailWidth=_thumbnailWidth;
@synthesize thumbnailHeight=_thumbnailHeight;
@synthesize snapshotPosition=_snapshotPosition;
@synthesize shouldRejectFrames=_shouldRejectFrames;

+ (VLCMediaThumbnailer *)thumbnailerWithMedia:(VLCMedia *)media andDelegate:(id<VLCMediaThumbnailerDelegate>)delegate
{
    id obj = [[[self class] alloc] init];
    [obj setMedia:media];
    [obj setDelegate:delegate];
    [obj setVLCLibrary: [VLCLibrary sharedLibrary]];
    return obj;
}

+ (VLCMediaThumbnailer *)thumbnailerWithMedia:(VLCMedia *)media delegate:(id<VLCMediaThumbnailerDelegate>)delegate andVLCLibrary:(nullable VLCLibrary *)library
{
    id obj = [[[self class] alloc] init];
    [obj setMedia:media];
    [obj setDelegate:delegate];
    if (library)
        [obj setVLCLibrary: library];
    else
        [obj setVLCLibrary: [VLCLibrary sharedLibrary]];
    return obj;
}

- (void)dealloc
{
    NSAssert(!_thumbnailingTimeoutTimer, @"Timer not released");
    NSAssert(!_parsingTimeoutTimer, @"Timer not released");
    NSAssert(!_data, @"Data not released");
    NSAssert(!_mp, @"Not properly retained");
    if (_thumbnail)
        CGImageRelease(_thumbnail);
}

- (void)setVLCLibrary:(VLCLibrary *)library
{
    _library = library;
}

- (void)fetchThumbnail
{
    NSAssert(!_data, @"We are already fetching a thumbnail");

    VLCMediaParsedStatus parsedStatus = [_media parsedStatus];
    if (!(parsedStatus == VLCMediaParsedStatusFailed || parsedStatus == VLCMediaParsedStatusDone)) {
        [_media addObserver:self forKeyPath:@"parsedStatus" options:0 context:NULL];
        [_media parseWithOptions:VLCMediaParseLocal | VLCMediaParseNetwork];
        NSAssert(!_parsingTimeoutTimer, @"We already have a timer around");
        _parsingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(mediaParsingTimedOut) userInfo:nil repeats:NO];
        return;
    }

    [self startFetchingThumbnail];
}

- (void)startFetchingThumbnail
{
    unsigned imageWidth = _thumbnailWidth > 0 ? _thumbnailWidth : kDefaultImageWidth;
    unsigned imageHeight = _thumbnailHeight > 0 ? _thumbnailHeight : kDefaultImageHeight;
    float snapshotPosition = _snapshotPosition > 0 ? _snapshotPosition : kSnapshotPosition;

    /* optimize rendering if we know what's ahead, if not, well not too bad either */
    VLCMediaVideoTrack *videoTrack = _media.videoTracks.firstObject.video;
    if (videoTrack) {
        int videoHeight = videoTrack.height;
        int videoWidth = videoTrack.width;

        // Constraining to the aspect ratio of the video.
        double ratio;
        if ((double)imageWidth / imageHeight < (double)videoWidth / videoHeight)
            ratio = (double)imageHeight / videoHeight;
        else
            ratio = (double)imageWidth / videoWidth;

        int newWidth = round(videoWidth * ratio);
        int newHeight = round(videoHeight * ratio);

        imageWidth = newWidth > 0 ? newWidth : imageWidth;
        imageHeight = newHeight > 0 ? newHeight : imageHeight;
    }

    _numberOfReceivedFrames = 0;
    NSAssert(!_shouldRejectFrames, @"Are we still running?");

    _effectiveThumbnailHeight = imageHeight;
    _effectiveThumbnailWidth = imageWidth;
    _snapshotPosition = snapshotPosition;

    _data = calloc(1, imageWidth * imageHeight * 4);
    NSAssert(_data, @"Can't create data");

    NSAssert(!_mp, @"We are already fetching a thumbnail");
    _mp = libvlc_media_player_new(_library.instance);
    if (_mp == NULL) {
        NSAssert(0, @"%s: creating the player instance failed", __PRETTY_FUNCTION__);
        [self endThumbnailing];
    }

    libvlc_media_add_option([_media libVLCMediaDescriptor], "no-audio");
    libvlc_media_add_option([_media libVLCMediaDescriptor], "no-spu");
    libvlc_media_add_option([_media libVLCMediaDescriptor], "avcodec-threads=1");
    libvlc_media_add_option([_media libVLCMediaDescriptor], "avcodec-skip-idct=4");
    libvlc_media_add_option([_media libVLCMediaDescriptor], "avcodec-skiploopfilter=3");
    libvlc_media_add_option([_media libVLCMediaDescriptor], "deinterlace=-1");
    libvlc_media_add_option([_media libVLCMediaDescriptor], "avi-index=3");
    libvlc_media_add_option([_media libVLCMediaDescriptor], "codec=avcodec,none");

    libvlc_media_player_set_media(_mp, [_media libVLCMediaDescriptor]);
    libvlc_video_set_format(_mp, "RGBA", imageWidth, imageHeight, 4 * imageWidth);
    libvlc_video_set_callbacks(_mp, lock, unlock, display, (__bridge void *)(self));
    if (snapshotPosition == kSnapshotPosition) {
        int length = _media.length.intValue;
        if (length < kStandardStartTime) {
            VKLog(@"short file detected");
            if (length > 1000) {
                VKLog(@"attempting seek to %is", (length * 25 / 100000));
                libvlc_media_add_option([_media libVLCMediaDescriptor], [[NSString stringWithFormat:@"start-time=%i", (length * 25 / 100000)] UTF8String]);
            }
        } else
            libvlc_media_add_option([_media libVLCMediaDescriptor], [[NSString stringWithFormat:@"start-time=%lli", (kStandardStartTime / 1000)] UTF8String]);
    }
    libvlc_media_player_play(_mp);

    NSURL *url = _media.url;
    NSTimeInterval timeoutDuration = 10;
    if (![url.scheme isEqualToString:@"file"]) {
        VKLog(@"media is remote, will wait longer");
        timeoutDuration = 45;
    }

    NSAssert(!_thumbnailingTimeoutTimer, @"We already have a timer around");
    _thumbnailingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeoutDuration target:self selector:@selector(mediaThumbnailingTimedOut) userInfo:nil repeats:NO];
}

- (void)mediaParsingTimedOut
{
    VKLog(@"WARNING: media thumbnailer media parsing timed out");
    [_media removeObserver:self forKeyPath:@"parsedStatus"];

    [self startFetchingThumbnail];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _media && [keyPath isEqualToString:@"parsedStatus"]) {
        [_parsingTimeoutTimer invalidate];
        _parsingTimeoutTimer = nil;
        [_media removeObserver:self forKeyPath:@"parsedStatus"];
        [self startFetchingThumbnail];

        return;
    }
    return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)didFetchThumbnail
{
    if (_shouldRejectFrames)
        return;

    // The video thread is blocking on us. Beware not to do too much work.
    _numberOfReceivedFrames++;

    float position = libvlc_media_player_get_position(_mp);
    long long length = libvlc_media_player_get_length(_mp);

    // Make sure we are getting the right frame
    if (position < self.snapshotPosition && _numberOfReceivedFrames < 2) {
        libvlc_media_player_set_position(_mp, self.snapshotPosition, YES);
        return;
    }
    if ((length < kStandardStartTime * 2 && _numberOfReceivedFrames < 5) && self.snapshotPosition == kSnapshotPosition) {
        libvlc_media_player_set_position(_mp, kSnapshotPosition, YES);
        return;
    }
    if ((position <= 0.05 && _numberOfReceivedFrames < 8) && length > 1000) {
        // Arbitrary choice to work around broken files.
        libvlc_media_player_set_position(_mp, kSnapshotPosition, YES);
        return;
    }
    // it isn't always best what comes first
    if (_numberOfReceivedFrames < 4) {
        return;
    }

    NSAssert(_data, @"We have no data");
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    const CGFloat width = _effectiveThumbnailWidth;
    const CGFloat height = _effectiveThumbnailHeight;
    const CGFloat pitch = 4 * width;
    CGContextRef bitmap = CGBitmapContextCreate(_data,
                                                width,
                                                height,
                                                8,
                                                pitch,
                                                colorSpace,
                                                kCGImageAlphaNoneSkipLast);

    CGColorSpaceRelease(colorSpace);
    NSAssert(bitmap, @"Can't create bitmap");

    // Create the thumbnail image
    //NSAssert(!_thumbnail, @"We already have a thumbnail");
    if (_thumbnail)
        CGImageRelease(_thumbnail);
    _thumbnail = CGBitmapContextCreateImage(bitmap);
    _thumbnailWidth = _effectiveThumbnailWidth;
    _thumbnailHeight = _effectiveThumbnailHeight;

    // Put a new context there.
    CGContextRelease(bitmap);

    // Make sure we don't block the video thread now
    [self performSelector:@selector(notifyDelegate) withObject:nil afterDelay:0];
}

- (void)stopAsync
{
    if (_mp) {
        libvlc_media_player_stop_async(_mp);
        libvlc_media_player_release(_mp);
        _mp = NULL;
    }

    // Now release data
    if (_data)
        free(_data);
    _data = NULL;

    _shouldRejectFrames = NO;
}

- (void)endThumbnailing
{
    _shouldRejectFrames = YES;

    [_thumbnailingTimeoutTimer invalidate];
    _thumbnailingTimeoutTimer = nil;

    [self performSelectorInBackground:@selector(stopAsync) withObject:nil];
}

- (void)notifyDelegate
{
    [self endThumbnailing];

    // Call delegate
    [_thumbnailingDelegate mediaThumbnailer:self didFinishThumbnail:_thumbnail];
}

- (void)mediaThumbnailingTimedOut
{
    VKLog(@"WARNING: media thumbnailer media thumbnailing timed out");
    [self endThumbnailing];

    // Call delegate
    [_thumbnailingDelegate mediaThumbnailerDidTimeOut:self];
}
@end
