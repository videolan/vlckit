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

#import "VLCMediaThumbnailer.h"
#import "VLCLibVLCBridging.h"


@interface VLCMediaThumbnailer ()
{
    id<VLCMediaThumbnailerDelegate> __weak _delegate;
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

    void * _internalLibVLCInstance;
}
- (void)didFetchThumbnail;
- (void)notifyDelegate;
- (void)fetchThumbnail;
- (void)startFetchingThumbnail;
@property (readonly, assign) void *dataPointer;
@property (readonly, assign) BOOL shouldRejectFrames;
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
    VLCMediaThumbnailer *thumbnailer = (__bridge VLCMediaThumbnailer *)(opaque);
    assert(!picture);

    assert([thumbnailer dataPointer] == *p_pixels);

    // We may already have a thumbnail if we are receiving picture after the first one.
    // Just ignore.
    if ([thumbnailer thumbnail] || [thumbnailer shouldRejectFrames])
        return;

    [thumbnailer performSelectorOnMainThread:@selector(didFetchThumbnail) withObject:nil waitUntilDone:YES];
}

@implementation VLCMediaThumbnailer
@synthesize media=_media;
@synthesize delegate=_delegate;
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
    [obj setLibVLCinstance:[VLCLibrary sharedInstance]];
    return obj;
}

+ (VLCMediaThumbnailer *)thumbnailerWithMedia:(VLCMedia *)media delegate:(id<VLCMediaThumbnailerDelegate>)delegate andVLCLibrary:(VLCLibrary *)library
{
    id obj = [[[self class] alloc] init];
    [obj setMedia:media];
    [obj setDelegate:delegate];
    if (library)
        [obj setLibVLCinstance:library.instance];
    else
        [obj setLibVLCinstance:[VLCLibrary sharedInstance]];
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
    if (_internalLibVLCInstance)
        libvlc_release(_internalLibVLCInstance);
}

- (void)setLibVLCinstance:(void *)libVLCinstance
{
    _internalLibVLCInstance = libVLCinstance;
    libvlc_retain(_internalLibVLCInstance);
}

- (void *)libVLCinstance
{
    return _internalLibVLCInstance;
}

- (void)fetchThumbnail
{
    NSAssert(!_data, @"We are already fetching a thumbnail");

    if (![_media isParsed]) {
        [_media addObserver:self forKeyPath:@"parsed" options:0 context:NULL];
        [_media synchronousParse];
        NSAssert(!_parsingTimeoutTimer, @"We already have a timer around");
        _parsingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(mediaParsingTimedOut) userInfo:nil repeats:NO];
        return;
    }

    [self startFetchingThumbnail];
}

- (void)startFetchingThumbnail
{
    NSArray *tracks = [_media tracksInformation];

    // Find the video track
    NSDictionary *videoTrack = nil;
    for (NSDictionary *track in tracks) {
        NSString *type = track[VLCMediaTracksInformationType];
        if ([type isEqualToString:VLCMediaTracksInformationTypeVideo]) {
            videoTrack = track;
            break;
        }
    }

    unsigned imageWidth = _thumbnailWidth > 0 ? _thumbnailWidth : kDefaultImageWidth;
    unsigned imageHeight = _thumbnailHeight > 0 ? _thumbnailHeight : kDefaultImageHeight;
    float snapshotPosition = _snapshotPosition > 0 ? _snapshotPosition : kSnapshotPosition;

    if (!videoTrack) {
        VKLog(@"WARNING: Can't find video track info, skipping file");
        [_parsingTimeoutTimer invalidate];
        _parsingTimeoutTimer = nil;
        [self mediaThumbnailingTimedOut];
        return;
    } else {
        int videoHeight = [videoTrack[VLCMediaTracksInformationVideoHeight] intValue];
        int videoWidth = [videoTrack[VLCMediaTracksInformationVideoWidth] intValue];

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

    _data = calloc(1, imageWidth * imageHeight * 4);
    NSAssert(_data, @"Can't create data");

    NSAssert(!_mp, @"We are already fetching a thumbnail");
    _mp = libvlc_media_player_new(self.libVLCinstance);

    libvlc_media_add_option([_media libVLCMediaDescriptor], "no-audio");

    libvlc_media_player_set_media(_mp, [_media libVLCMediaDescriptor]);
    libvlc_video_set_format(_mp, "RGBA", imageWidth, imageHeight, 4 * imageWidth);
    libvlc_video_set_callbacks(_mp, lock, unlock, NULL, (__bridge void *)(self));
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

    NSAssert(!_thumbnailingTimeoutTimer, @"We already have a timer around");
    _thumbnailingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(mediaThumbnailingTimedOut) userInfo:nil repeats:NO];
}

- (void)mediaParsingTimedOut
{
    VKLog(@"WARNING: media thumbnailer media parsing timed out");
    [_media removeObserver:self forKeyPath:@"parsed"];

    [self startFetchingThumbnail];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _media && [keyPath isEqualToString:@"parsed"]) {
        if ([_media isParsed]) {
            [_parsingTimeoutTimer invalidate];
            _parsingTimeoutTimer = nil;
            [_media removeObserver:self forKeyPath:@"parsed"];
            [self startFetchingThumbnail];
        }
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
        libvlc_media_player_set_position(_mp, self.snapshotPosition);
        return;
    }
    if ((length < kStandardStartTime * 2 && _numberOfReceivedFrames < 5) && self.snapshotPosition == kSnapshotPosition) {
        libvlc_media_player_set_position(_mp, kSnapshotPosition);
        return;
    }
    if ((position <= 0.05 && _numberOfReceivedFrames < 8) && length > 1000) {
        // Arbitrary choice to work around broken files.
        libvlc_media_player_set_position(_mp, kSnapshotPosition);
        return;
    }
    // it isn't always best what comes first
    if (_numberOfReceivedFrames < 4)
        return;

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

    // Put a new context there.
    CGContextRelease(bitmap);

    // Make sure we don't block the video thread now
    [self performSelector:@selector(notifyDelegate) withObject:nil afterDelay:0];
}

- (void)stopAsync
{
    if (_mp) {
        libvlc_media_player_stop(_mp);
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
    [_delegate mediaThumbnailer:self didFinishThumbnail:_thumbnail];

}

- (void)mediaThumbnailingTimedOut
{
    VKLog(@"WARNING: media thumbnailer media thumbnailing timed out");
    [self endThumbnailing];

    // Call delegate
    [_delegate mediaThumbnailerDidTimeOut:self];
}
@end
