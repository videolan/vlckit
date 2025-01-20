/*****************************************************************************
 * VLCMedia.m: VLCKit.framework VLCMedia implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2013, 2017 Felix Paul Kühne
 * Copyright (C) 2007, 2013 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *          Felix Paul Kühne <fkuehne # videolan.org>
 *          Soomin Lee <TheHungryBu # gmail.com>
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

#import <VLCMedia.h>
#import <VLCMediaList.h>
#import <VLCLibrary.h>
#import <VLCLibVLCBridging.h>
#import <VLCTime.h>
#import <VLCMediaMetaData.h>
#import <VLCEventsHandler.h>
#import <vlc/libvlc.h>
#import <sys/sysctl.h> // for sysctlbyname

/* Notification Messages */
NSNotificationName const VLCMediaMetaChangedNotification = @"VLCMediaMetaChangedNotification";

/******************************************************************************
 * VLC callbacks for streaming.
 */
int open_cb(void *opaque, void **datap, uint64_t *sizep) {
    NSInputStream *stream = (__bridge NSInputStream *)(opaque);
    
    *datap = opaque;
    *sizep = UINT64_MAX;
    
    // Once a stream is closed, it cannot be reopened.
    if (stream && stream.streamStatus == NSStreamStatusNotOpen) {
        [stream open];
        return 0;
    } else {
        return stream.streamStatus == NSStreamStatusOpen ? 0 : -1;
    }
}

ssize_t read_cb(void *opaque, unsigned char *buf, size_t len) {
    NSInputStream *stream = (__bridge NSInputStream *)(opaque);
    if (!stream) {
        return -1;
    }
    
    return [stream read:buf maxLength:len];
}

int seek_cb(void *opaque, uint64_t offset) {
    NSInputStream *stream = (__bridge NSInputStream *)(opaque);
    if (!stream) {
        return -1;
    }
    
    /*
     By default, NSStream instances that are not file-based are non-seekable, one-way streams (although custom seekable subclasses are possible).
     Once the data has been provided or consumed, the data cannot be retrieved from the stream.
     
     However, you may want a peer subclass to NSInputStream whose instances are capable of seeking through a stream.
     */
    return [stream setProperty:@(offset) forKey:NSStreamFileCurrentOffsetKey] ? 0 : -1;
}

void close_cb(void *opaque) {
    NSInputStream *stream = (__bridge NSInputStream *)(opaque);
    if (stream && stream.streamStatus != NSStreamStatusClosed && stream.streamStatus != NSStreamStatusNotOpen) {
        [stream close];
    }
    return;
}

/******************************************************************************
 * VLCMedia ()
 */
@interface VLCMedia()
{
    void *                  p_md;                   ///< Internal media descriptor instance
    NSInputStream           *stream;                ///< Stream object if instance is initialized via NSInputStream to pass to callbacks
    _Nullable id            _userData;              /// libvlc_media_user_data
    VLCEventsHandler*       _eventsHandler;          /// handles libvlc callbacks
    VLCMediaMetaData *_metaData;
}

/* Make our properties internally readwrite */
@property (nonatomic, readwrite, strong, nullable) VLCMediaList * subitems;

- (void)parseIfNeeded;

/* Callback Methods */
- (void)parsedChanged;
- (void)metaChanged:(const libvlc_meta_t)metaType;
- (void)subItemAdded;

@end

/******************************************************************************
 * LibVLC Event Callback
 */
static void HandleMediaMetaChanged(const libvlc_event_t * event, void * opaque)
{
    @autoreleasepool {
        const libvlc_meta_t meta_type = event->u.media_meta_changed.meta_type;
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler*)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMedia *media = (VLCMedia *)object;
            [media metaChanged:meta_type];
        }];
    }
}

static void HandleMediaDurationChanged(const libvlc_event_t * event, void * opaque)
{
    @autoreleasepool {
        VLCTime *time = [VLCTime timeWithNumber: @(event->u.media_duration_changed.new_duration)];
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler*)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMedia *media = (VLCMedia *)object;
            [media setLength:time];
        }];
    }
}

static void HandleMediaSubItemAdded(const libvlc_event_t * event, void * opaque)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler*)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMedia *media = (VLCMedia *)object;
            [media subItemAdded];
        }];
    }
}

static void HandleMediaParsedChanged(const libvlc_event_t * event, void * opaque)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler*)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMedia *media = (VLCMedia *)object;
            [media parsedChanged];
        }];
    }
}

static const struct event_handler_entry {
    libvlc_event_type_t type;
    libvlc_callback_t callback;
} event_entries[] =
{
    { libvlc_MediaMetaChanged,          HandleMediaMetaChanged },
    { libvlc_MediaDurationChanged,      HandleMediaDurationChanged },
    { libvlc_MediaSubItemAdded,         HandleMediaSubItemAdded },
    { libvlc_MediaParsedChanged,        HandleMediaParsedChanged },
};

/******************************************************************************
 * Implementation
 */
@implementation VLCMedia

+ (NSString *)codecNameForFourCC:(uint32_t)fourcc trackType:(VLCMediaTrackType)trackType
{
    libvlc_track_type_t track_type = (libvlc_track_type_t)trackType;
    const char *ret = libvlc_media_get_codec_description(track_type, fourcc);
    return ret != NULL ? @(ret) : @"";
}

+ (nullable instancetype)mediaWithURL:(NSURL *)anURL;
{
    return [[VLCMedia alloc] initWithURL:anURL];
}

+ (nullable instancetype)mediaWithPath:(NSString *)aPath;
{
    return [[VLCMedia alloc] initWithPath:aPath];
}

+ (nullable instancetype)mediaAsNodeWithName:(NSString *)aName;
{
    return [[VLCMedia alloc] initAsNodeWithName:aName];
}

- (nullable instancetype)initWithPath:(NSString *)aPath
{
    return [self initWithURL:[NSURL fileURLWithPath:aPath isDirectory:NO]];
}

- (nullable instancetype)initWithURL:(NSURL *)anURL
{
    if ([super init] == nil)
        return nil;

    const char *url = [[anURL absoluteString] UTF8String];
    p_md = libvlc_media_new_location(url);
    if (p_md == NULL)
        return nil;

    [self initInternalMediaDescriptor];
    return self;
}

- (nullable instancetype)initWithStream:(NSInputStream *)stream
{
    NSAssert(stream.streamStatus != NSStreamStatusClosed, @"Passing closed stream to VLCMedia.init does not work");
    if ([super init] == nil)
        return nil;

    self->stream = stream;
    p_md = libvlc_media_new_callbacks(open_cb, read_cb, seek_cb, close_cb, (__bridge void *)(stream));
    if (p_md == NULL)
        return nil;

    [self initInternalMediaDescriptor];
    return self;
}

- (nullable instancetype)initAsNodeWithName:(NSString *)aName
{
    if ([super init] == nil)
        return nil;

    p_md = libvlc_media_new_as_node([aName UTF8String]);
    if (p_md == NULL)
        return nil;

    [self initInternalMediaDescriptor];
    return self;
}

- (void)dealloc
{
    if (_eventsHandler)
    {
        /* We unbind each event from the handler defined in the table above. */
        libvlc_event_manager_t * p_em = libvlc_media_event_manager(p_md);
        size_t entry_count = sizeof(event_entries)/sizeof(event_entries[0]);
        for (size_t i=0; i<entry_count; ++i)
        {
            const struct event_handler_entry *entry = &event_entries[i];
            libvlc_event_detach(p_em, entry->type, entry->callback, (__bridge void *)(_eventsHandler));
        }
    }

    if (p_md)
        libvlc_media_release(p_md);
}

- (VLCMediaType)mediaType
{
    libvlc_media_type_t libmediatype = libvlc_media_get_type(p_md);

    switch (libmediatype) {
        case libvlc_media_type_file:
            return VLCMediaTypeFile;
        case libvlc_media_type_directory:
            return VLCMediaTypeDirectory;
        case libvlc_media_type_disc:
            return VLCMediaTypeDisc;
        case libvlc_media_type_stream:
            return VLCMediaTypeStream;
        case libvlc_media_type_playlist:
            return VLCMediaTypePlaylist;

        default:
            return VLCMediaTypeUnknown;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>, md: %p, url: %@", [self class], self, p_md, [[_url absoluteString] stringByRemovingPercentEncoding]];
}

- (NSComparisonResult)compare:(nullable VLCMedia *)media
{
    if (self == media)
        return NSOrderedSame;
    if (!media)
        return NSOrderedDescending;
    return p_md == [media libVLCMediaDescriptor] ? NSOrderedSame : NSOrderedAscending;
}

- (BOOL)isEqual:(id)other
{
    return ([other isKindOfClass: [VLCMedia class]] &&
            [other libVLCMediaDescriptor] == p_md);
}

- (VLCTime *)length
{
    if (!_length) {
        // Try figuring out what the length is
        long long duration = libvlc_media_get_duration( p_md );
        if (duration < 0)
            return [VLCTime nullTime];
         _length = [VLCTime timeWithNumber:@(duration)];
    }
    return _length;
}

- (VLCTime *)lengthWaitUntilDate:(NSDate *)aDate
{
    static const long long thread_sleep = 10000;

    if (!_length) {
        // Force parsing of this item.
        [self parseIfNeeded];

        // wait until we are preparsed
       libvlc_media_parsed_status_t status = libvlc_media_get_parsed_status(p_md);
       while (!_length && !(status == VLCMediaParsedStatusFailed || status == VLCMediaParsedStatusDone) && [aDate timeIntervalSinceNow] > 0) {
          usleep( thread_sleep );
          status = libvlc_media_get_parsed_status(p_md);
       }

        // So we're done waiting, but sometimes we trap the fact that the parsing
        // was done before the length gets assigned, so lets go ahead and assign
        // it ourselves.
        if (!_length)
            return [self length];
    }

    return _length;
}

- (VLCMediaParsedStatus)parsedStatus
{
    libvlc_media_parsed_status_t status = libvlc_media_get_parsed_status(p_md);
    return (VLCMediaParsedStatus)status;
}

- (int)parseWithOptions:(VLCMediaParsingOptions)options
                timeout:(int)timeoutValue
                library:(VLCLibrary*)library
{
    // we are using the default time-out value
    return libvlc_media_parse_request([library instance],
                                      p_md,
                                      options,
                                      timeoutValue);
}

- (int)parseWithOptions:(VLCMediaParsingOptions)options timeout:(int)timeoutValue
{
    // we are using the default time-out value
    return [self parseWithOptions:options
                          timeout:timeoutValue
                          library:[VLCLibrary sharedLibrary]];
}

- (int)parseWithOptions:(VLCMediaParsingOptions)options
{
    return [self parseWithOptions:options
                           timeout:-1
                          library:[VLCLibrary sharedLibrary]];
}

- (void)parseStop:(VLCLibrary*)library
{
    libvlc_media_parse_stop([library instance], p_md);
}

- (void)parseStop
{
    libvlc_media_parse_stop([[VLCLibrary sharedLibrary] instance], p_md);
}

- (void)addOption:(NSString *)option
{
    libvlc_media_add_option(p_md, [option UTF8String]);
}

- (void)addOptions:(NSDictionary*)options
{
    [options enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (![obj isKindOfClass:[NSNull class]])
            libvlc_media_add_option(p_md, [[NSString stringWithFormat:@"%@=%@", key, obj] UTF8String]);
        else
            libvlc_media_add_option(p_md, [key UTF8String]);
    }];
}

- (int)storeCookie:(NSString *)cookie
           forHost:(NSString *)host
              path:(NSString *)path
{
    if (cookie == NULL || host == NULL || path == NULL) {
        return -1;
    }
#if TARGET_OS_IPHONE
    return libvlc_media_cookie_jar_store(p_md,
                                         [cookie UTF8String],
                                         [host UTF8String],
                                         [path UTF8String]);
#else
    return -1;
#endif
}

- (void)clearStoredCookies
{
#if TARGET_OS_IPHONE
    libvlc_media_cookie_jar_clear(p_md);
#endif
}

- (VLCMediaFileStatReturnType)fileStatValueForType:(const VLCMediaFileStatType)type value:(uint64_t *)value
{
    if (value == NULL)
        return VLCMediaFileStatReturnTypeError;
    
    return libvlc_media_get_filestat(p_md, type, value);
}

- (VLCMediaStats)statistics
{
    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);
    VLCMediaStats stats = {
        .readBytes          = p_stats.i_read_bytes,
        .inputBitrate       = p_stats.f_input_bitrate,
        .demuxReadBytes     = p_stats.i_demux_read_bytes,
        .demuxBitrate       = p_stats.f_demux_bitrate,
        .demuxCorrupted     = p_stats.i_demux_corrupted,
        .demuxDiscontinuity = p_stats.i_demux_discontinuity,
        .decodedVideo       = p_stats.i_decoded_video,
        .decodedAudio       = p_stats.i_decoded_audio,
        .displayedPictures  = p_stats.i_displayed_pictures,
        .latePictures       = p_stats.i_late_pictures,
        .lostPictures       = p_stats.i_lost_pictures,
        .playedAudioBuffers = p_stats.i_played_abuffers,
        .lostAudioBuffers   = p_stats.i_lost_abuffers
    };
    return stats;
}

- (NSArray<VLCMediaTrack *> *)tracksInformation
{
    NSMutableArray<VLCMediaTrack *> *array = @[].mutableCopy;
    
    // 3 = (libvlc_track_audio = 0 | libvlc_track_video = 1 | libvlc_track_text = 2)
    for (libvlc_track_type_t type = 0; type < 3; type++) {
        libvlc_media_tracklist_t *tracklist = libvlc_media_get_tracklist(p_md, type);
        if (!tracklist) continue;
        
        size_t tracklistCount = libvlc_media_tracklist_count(tracklist);
        for (size_t index = 0; index < tracklistCount; index++) {
            libvlc_media_track_t *track = libvlc_media_tracklist_at(tracklist, index);
            VLCMediaTrack *info = [[VLCMediaTrack alloc] initWithMediaTrack: track];
            if (info)
                [array addObject: info];
        }
        
        libvlc_media_tracklist_delete(tracklist);
    }
    
    return array;
}

- (nullable id)userData
{
    return (__bridge _Nullable id)libvlc_media_get_user_data(p_md);
}

- (void)setUserData:(nullable id)userData
{
    _userData = userData;
    
    libvlc_media_set_user_data(p_md, (__bridge void *)userData);
}

/******************************************************************************
 * Implementation VLCMedia ()
 */
- (void)initInternalMediaDescriptor
{
    char * p_url = libvlc_media_get_mrl( p_md );
    if (!p_url)
        return;

    NSString *urlString = @(p_url);
    free(p_url);
    
    if (!urlString)
        return;
    
    /* Attempt to interpret as a file path then */
    _url = [NSURL URLWithString: urlString] ?: [NSURL fileURLWithPath: urlString];
    if (!_url)
        return;


    /* We bind each event to the handler defined in the table above. */
    libvlc_event_manager_t * p_em = libvlc_media_event_manager(p_md);
    size_t entry_count = sizeof(event_entries)/sizeof(event_entries[0]);
    _eventsHandler = [VLCEventsHandler handlerWithObject:self configuration:[VLCLibrary sharedEventsConfiguration]];
    for (size_t i=0; i<entry_count; ++i)
    {
        const struct event_handler_entry *entry = &event_entries[i];
        libvlc_event_attach(p_em, entry->type, entry->callback, (__bridge void *)(_eventsHandler));
    }

    libvlc_media_list_t * p_mlist = libvlc_media_subitems( p_md );

    if (p_mlist) {
        self.subitems = [VLCMediaList mediaListWithLibVLCMediaList:p_mlist];
        libvlc_media_list_release( p_mlist );
    }
}

- (void)parseIfNeeded
{
    VLCMediaParsedStatus parsedStatus = [self parsedStatus];
    if (parsedStatus == VLCMediaParsedStatusSkipped || parsedStatus == VLCMediaParsedStatusInit)
        [self parseWithOptions:VLCMediaParseLocal | VLCMediaFetchLocal];
}

- (void)metaChanged:(const libvlc_meta_t)metaType
{
    [self.metaData handleMediaMetaChanged: metaType];

    if ([_delegate respondsToSelector:@selector(mediaMetaDataDidChange:)])
        [_delegate mediaMetaDataDidChange:self];
}

- (void)subItemAdded
{
    if (_subitems)
        return; /* Nothing to do */

    libvlc_media_list_t * p_mlist = libvlc_media_subitems( p_md );

    NSAssert( p_mlist, @"The mlist shouldn't be nil, we are receiving a subItemAdded");

    self.subitems = [VLCMediaList mediaListWithLibVLCMediaList:p_mlist];

    libvlc_media_list_release( p_mlist );
}

- (void)parsedChanged
{
    [self willChangeValueForKey:@"parsedStatus"];
    [self parsedStatus];
    [self didChangeValueForKey:@"parsedStatus"];
    
    if ([_delegate respondsToSelector:@selector(mediaDidFinishParsing:)])
        [_delegate mediaDidFinishParsing:self];
}

@end

/******************************************************************************
 * Implementation VLCMedia (LibVLCBridging)
 */
@implementation VLCMedia (LibVLCBridging)

+ (nullable instancetype)mediaWithLibVLCMediaDescriptor:(void *)md
{
    return [[VLCMedia alloc] initWithLibVLCMediaDescriptor:md];
}

+ (nullable instancetype)mediaWithMedia:(VLCMedia *)media andLibVLCOptions:(NSDictionary *)options
{
    libvlc_media_t * p_md;
    p_md = libvlc_media_duplicate([media libVLCMediaDescriptor]);

    for (NSString * key in [options allKeys]) {
        if (options[key] != [NSNull null])
            libvlc_media_add_option(p_md, [[NSString stringWithFormat:@"%@=%@", key, options[key]] UTF8String]);
        else
            libvlc_media_add_option(p_md, [[NSString stringWithFormat:@"%@", key] UTF8String]);
    }
    return [VLCMedia mediaWithLibVLCMediaDescriptor:p_md];
}

- (nullable instancetype)initWithLibVLCMediaDescriptor:(void *)md
{
    if ([super init] == nil)
        return nil;
    libvlc_media_retain(md);
    p_md = md;

    _userData = (__bridge _Nullable id)libvlc_media_get_user_data(p_md);
    [self initInternalMediaDescriptor];
    return self;
}

- (void *)libVLCMediaDescriptor
{
    return p_md;
}


@end


#pragma mark VLCMedia+MetaData

@implementation VLCMedia (MetaData)

- (VLCMediaMetaData *)metaData
{
    if (!_metaData)
        _metaData = [[VLCMediaMetaData alloc] initWithMedia: self];
    return _metaData;
}

@end


#pragma mark - VLCMedia+Tracks

/**
 * VLCMedia+Tracks
 */
@implementation VLCMedia (Tracks)

#pragma mark - Audio Tracks

- (NSArray<VLCMediaTrack *> *)audioTracks
{
    return [self _tracksForType: libvlc_track_audio];
}

#pragma mark - Video Tracks

- (NSArray<VLCMediaTrack *> *)videoTracks
{
    return [self _tracksForType: libvlc_track_video];
}

#pragma mark - Text Tracks

- (NSArray<VLCMediaTrack *> *)textTracks
{
    return [self _tracksForType: libvlc_track_text];
}

#pragma mark - Private

- (NSArray<VLCMediaTrack *> *)_tracksForType:(const libvlc_track_type_t)type
{
    libvlc_media_tracklist_t *tracklist = libvlc_media_get_tracklist(p_md, type);
    if (!tracklist)
        return @[];
    
    const size_t tracklistCount = libvlc_media_tracklist_count(tracklist);
    NSMutableArray<VLCMediaTrack *> *tracks = [NSMutableArray arrayWithCapacity: (NSUInteger)tracklistCount];
    for (size_t i = 0; i < tracklistCount; i++) {
        libvlc_media_track_t *track_t = libvlc_media_tracklist_at(tracklist, i);
        VLCMediaTrack *track = [[VLCMediaTrack alloc] initWithMediaTrack: track_t];
        if (track)
            [tracks addObject: track];
    }
    libvlc_media_tracklist_delete(tracklist);
    return tracks;
}

@end


/******************************************************************************
 * Implementation VLCMediaTrack
 */
@implementation VLCMediaTrack

- (nullable instancetype)initWithMediaTrack:(libvlc_media_track_t *)track
{
    if ([super init] == nil)
        return nil;

    _type = (VLCMediaTrackType)track->i_type;
    _codec = track->i_codec;
    _fourcc = track->i_original_fourcc;
    _identifier = track->i_id;
    _profile = track->i_profile;
    _level = track->i_level;
    _bitrate = track->i_bitrate;

    if (track->psz_language)
        _language = @(track->psz_language);

    if (track->psz_description)
        _trackDescription = @(track->psz_description);

    if (track->i_type == libvlc_track_audio && track->audio)
        _audio = [[VLCMediaAudioTrack alloc] initWithAudioTrack: track->audio];
    else if (track->i_type == libvlc_track_video && track->video)
        _video = [[VLCMediaVideoTrack alloc] initWithVideoTrack: track->video];
    else if (track->i_type == libvlc_track_text && track->subtitle)
        _text = [[VLCMediaTextTrack alloc] initWithSubtitleTrack: track->subtitle];
    return self;
}

- (NSString *)codecName
{
    return [VLCMedia codecNameForFourCC: _fourcc trackType: _type];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>, codec: %d, fourcc: %d, codecName: %@, identifier: %d, profile: %d, level: %d, bitrate: %d, language: %@, trackDescription: %@, audio: %@, video: %@, text: %@", [self class], self, _codec, _fourcc, [self codecName], _identifier, _profile, _level, _bitrate, _language, _trackDescription, [_audio description], [_video description], [_text description]];
}

@end


/******************************************************************************
 * Implementation VLCMediaAudioTrack
 */
@implementation VLCMediaAudioTrack

- (nullable instancetype)initWithAudioTrack:(libvlc_audio_track_t *)audio
{
    if ([super init] == nil)
        return nil;
    _channelsNumber = audio->i_channels;
    _rate = audio->i_rate;
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>, channelsNumber: %d, rate: %d", [self class], self, _channelsNumber, _rate];
}

@end


/******************************************************************************
 * Implementation VLCMediaVideoTrack
 */
@implementation VLCMediaVideoTrack

- (nullable instancetype)initWithVideoTrack:(libvlc_video_track_t *)video
{
    if ([super init] == nil)
        return nil;
    _width = video->i_width;
    _height = video->i_height;
    _orientation = (VLCMediaOrientation)video->i_orientation;
    _projection = (VLCMediaProjection)video->i_projection;
    _sourceAspectRatio = video->i_sar_num;
    _sourceAspectRatioDenominator = video->i_sar_den;
    _frameRate = video->i_frame_rate_num;
    _frameRateDenominator = video->i_frame_rate_den;
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>, width: %d, height: %d, orientation: %lu, projection: %lu, sourceAspectRatio: %d, sourceAspectRatioDenominator: %d, frameRate: %d, frameRateDenominator: %d", [self class], self, _width, _height, _orientation, _projection, _sourceAspectRatio, _sourceAspectRatioDenominator, _frameRate, _frameRateDenominator];
}

@end


/******************************************************************************
 * Implementation VLCMediaTextTrack
 */
@implementation VLCMediaTextTrack

- (nullable instancetype)initWithSubtitleTrack:(libvlc_subtitle_track_t *)subtitle
{
    if ([super init] == nil)
        return nil;

    if (subtitle->psz_encoding)
        _encoding = @(subtitle->psz_encoding);
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>, encoding: %@", [self class], self, _encoding];
}

@end

/******************************************************************************
 * Implementation VLCMediaPlayerTrack
 */
@implementation VLCMediaPlayerTrack
{
    __weak VLCMediaPlayer *_mediaPlayer;
}

- (nullable instancetype)initWithMediaTrack:(libvlc_media_track_t *)track mediaPlayer:(VLCMediaPlayer *)mediaPlayer;
{
    if ([super initWithMediaTrack: track] == nil)
        return nil;
    _mediaPlayer = mediaPlayer;
    _trackId = @(track->psz_id);
    _idStable = track->id_stable;
    _trackName = track->psz_name ? @(track->psz_name) : @"";
    return self;
}

- (BOOL)isSelected
{
    libvlc_media_player_t *p_mi = (libvlc_media_player_t *)_mediaPlayer.libVLCMediaPlayer;
    if (!p_mi)
        return NO;
    
    const char *psz_id = self.trackId.UTF8String;
    libvlc_media_track_t *track_t = libvlc_media_player_get_track_from_id(p_mi, psz_id);
    if (!track_t)
        return NO;
    
    const BOOL selected = track_t->selected;
    libvlc_media_track_release(track_t);
    return selected;
}

- (BOOL)isSelectedExclusively
{
    libvlc_media_player_t *p_mi = (libvlc_media_player_t*)_mediaPlayer.libVLCMediaPlayer;
    assert(p_mi);

    const char *psz_id = [self.trackId UTF8String];
    libvlc_media_track_t *track_t = libvlc_media_player_get_track_from_id(p_mi, psz_id);
    if (!track_t)
        return NO;

    const BOOL selected = track_t->selected;
    // TODO: check only selected
    libvlc_media_track_release(track_t);
    return selected;
}

- (void)setSelectedExclusively:(BOOL)selected
{
    libvlc_media_player_t *p_mi = (libvlc_media_player_t *)_mediaPlayer.libVLCMediaPlayer;
    if (!p_mi)
        return;

    const char *psz_id = self.trackId.UTF8String;
    libvlc_media_track_t *track_t = libvlc_media_player_get_track_from_id(p_mi, psz_id);
    if (!track_t)
        return;
    libvlc_media_player_select_track(p_mi, track_t);
    libvlc_media_track_release(track_t);
}
- (void)setSelected:(BOOL)selected
{
    libvlc_media_player_t *p_mi = (libvlc_media_player_t *)_mediaPlayer.libVLCMediaPlayer;
    if (!p_mi)
        return;
    
    const libvlc_track_type_t type = (libvlc_track_type_t)self.type;
    libvlc_media_tracklist_t *selected_tracklist_t = libvlc_media_player_get_tracklist(p_mi, type, true);
    if (!selected_tracklist_t)
        return;
    
    const size_t selectedTracklistCount = libvlc_media_tracklist_count(selected_tracklist_t);
    NSMutableArray<NSString *> *selectedTrackIDs = [NSMutableArray arrayWithCapacity: (NSUInteger)selectedTracklistCount];
    for (size_t i = 0; i < selectedTracklistCount; i++) {
        libvlc_media_track_t *selected_track_t = libvlc_media_tracklist_at(selected_tracklist_t, i);
        [selectedTrackIDs addObject: @(selected_track_t->psz_id)];
    }
    libvlc_media_tracklist_delete(selected_tracklist_t);
    
    NSString * const ownTrackId = _trackId;
    const BOOL isSameTrack = [selectedTrackIDs containsObject: ownTrackId];
    
    // already selected || already deselected
    if ((selected && isSameTrack) || (!selected && !isSameTrack))
        return;
    
    selected ? [selectedTrackIDs addObject: ownTrackId] : [selectedTrackIDs removeObject: ownTrackId];
    
    if (type == libvlc_track_audio && selectedTrackIDs.count >= 2) {
        VKLog(@"WARNING: selecting multiple audio tracks is currently not supported.");
        return;
    }
    
    if (!selectedTrackIDs.count) {
        libvlc_media_player_unselect_track_type(p_mi, type);
        return;
    }
    
    const char *psz_ids = [selectedTrackIDs componentsJoinedByString: @","].UTF8String;
    libvlc_media_player_select_tracks_by_ids(p_mi, type, psz_ids);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@, trackId: %@, isIdStable: %d, trackName: %@, isSelected: %d", super.description, self.trackId, self.isIdStable, self.trackName, self.isSelected];
}

- (BOOL)isEqual:(id)other
{
    VLCMediaPlayerTrack *otherTrack = (VLCMediaPlayerTrack *)other;
    return ([otherTrack isKindOfClass: VLCMediaPlayerTrack.class] &&
            otherTrack.type == self.type &&
            [otherTrack.trackId isEqualToString: self.trackId]);
}

- (NSUInteger)hash
{
    return self.description.hash;
}

@end
