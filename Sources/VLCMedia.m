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

#import "VLCMedia.h"
#import "VLCMediaList.h"
#import "VLCEventManager.h"
#import "VLCLibrary.h"
#import "VLCLibVLCBridging.h"
#import <vlc/libvlc.h>
#import <sys/sysctl.h> // for sysctlbyname

/* Meta Dictionary Keys */
NSString *const VLCMetaInformationTitle          = @"title";
NSString *const VLCMetaInformationArtist         = @"artist";
NSString *const VLCMetaInformationGenre          = @"genre";
NSString *const VLCMetaInformationCopyright      = @"copyright";
NSString *const VLCMetaInformationAlbum          = @"album";
NSString *const VLCMetaInformationTrackNumber    = @"trackNumber";
NSString *const VLCMetaInformationDescription    = @"description";
NSString *const VLCMetaInformationRating         = @"rating";
NSString *const VLCMetaInformationDate           = @"date";
NSString *const VLCMetaInformationSetting        = @"setting";
NSString *const VLCMetaInformationURL            = @"url";
NSString *const VLCMetaInformationLanguage       = @"language";
NSString *const VLCMetaInformationNowPlaying     = @"nowPlaying";
NSString *const VLCMetaInformationPublisher      = @"publisher";
NSString *const VLCMetaInformationEncodedBy      = @"encodedBy";
NSString *const VLCMetaInformationArtworkURL     = @"artworkURL";
NSString *const VLCMetaInformationArtwork        = @"artwork";
NSString *const VLCMetaInformationTrackID        = @"trackID";
NSString *const VLCMetaInformationTrackTotal     = @"trackTotal";
NSString *const VLCMetaInformationDirector       = @"director";
NSString *const VLCMetaInformationSeason         = @"season";
NSString *const VLCMetaInformationEpisode        = @"episode";
NSString *const VLCMetaInformationShowName       = @"showName";
NSString *const VLCMetaInformationActors         = @"actors";
NSString *const VLCMetaInformationAlbumArtist    = @"AlbumArtist";
NSString *const VLCMetaInformationDiscNumber     = @"discNumber";

/* Notification Messages */
NSString *const VLCMediaMetaChanged              = @"VLCMediaMetaChanged";

/******************************************************************************
 * VLC callbacks for streaming.
 */
int open_cb(void *opaque, void **datap, uint64_t *sizep) {
    NSInputStream *stream = (__bridge NSInputStream *)(opaque);
    
    // Once a stream is closed, it cannot be reopened.
    if (stream && stream.streamStatus == NSStreamStatusNotOpen) {
        [stream open];
        *datap = opaque;
        *sizep = UINT64_MAX;
        return 0;
    }
    return stream.streamStatus == NSStreamStatusOpen ? 0 : -1;
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
    BOOL                    isArtFetched;           ///< Value used to determine of the artwork has been parsed
    BOOL                    areOthersMetaFetched;   ///< Value used to determine of the other meta has been parsed
    BOOL                    isArtURLFetched;        ///< Value used to determine of the other meta has been preparsed
    NSMutableDictionary     *_metaDictionary;       ///< Dictionary to cache metadata read from libvlc
    NSInputStream           *stream;                ///< Stream object if instance is initialized via NSInputStream to pass to callbacks
}

/* Make our properties internally readwrite */
@property (nonatomic, readwrite) VLCMediaState state;
@property (nonatomic, readwrite, strong) VLCMediaList * subitems;

/* Statics */
+ (libvlc_meta_t)stringToMetaType:(NSString *)string;
+ (NSString *)metaTypeToString:(libvlc_meta_t)type;

/* Initializers */
- (void)initInternalMediaDescriptor;

/* Operations */
- (void)fetchMetaInformationFromLibVLCWithType:(NSString*)metaType;
#if !TARGET_OS_IPHONE
- (void)fetchMetaInformationForArtWorkWithURL:(NSString *)anURL;
- (void)setArtwork:(NSImage *)art;
#endif

- (void)parseIfNeeded;

/* Callback Methods */
- (void)parsedChanged:(NSNumber *)isParsedAsNumber;
- (void)metaChanged:(NSString *)metaType;
- (void)subItemAdded;
- (void)setStateAsNumber:(NSNumber *)newStateAsNumber;

@end

static VLCMediaState libvlc_state_to_media_state[] =
{
    [libvlc_NothingSpecial] = VLCMediaStateNothingSpecial,
    [libvlc_Stopped]        = VLCMediaStateNothingSpecial,
    [libvlc_Opening]        = VLCMediaStateNothingSpecial,
    [libvlc_Buffering]      = VLCMediaStateBuffering,
    [libvlc_Ended]          = VLCMediaStateNothingSpecial,
    [libvlc_Error]          = VLCMediaStateError,
    [libvlc_Playing]        = VLCMediaStatePlaying,
    [libvlc_Paused]         = VLCMediaStatePlaying,
};

static inline VLCMediaState LibVLCStateToMediaState( libvlc_state_t state )
{
    return libvlc_state_to_media_state[state];
}

/******************************************************************************
 * LibVLC Event Callback
 */
static void HandleMediaMetaChanged(const libvlc_event_t * event, void * self)
{
    @autoreleasepool {
        [[VLCEventManager sharedManager] callOnMainThreadObject:(__bridge id)(self)
                                                     withMethod:@selector(metaChanged:)
                                           withArgumentAsObject:[VLCMedia metaTypeToString:event->u.media_meta_changed.meta_type]];
    }
}

static void HandleMediaDurationChanged(const libvlc_event_t * event, void * self)
{
    @autoreleasepool {
        [[VLCEventManager sharedManager] callOnMainThreadObject:(__bridge id)(self)
                                                     withMethod:@selector(setLength:)
                                           withArgumentAsObject:[VLCTime timeWithNumber:
                                               @(event->u.media_duration_changed.new_duration)]];
    }
}

static void HandleMediaStateChanged(const libvlc_event_t * event, void * self)
{
    @autoreleasepool {
        [[VLCEventManager sharedManager] callOnMainThreadObject:(__bridge id)(self)
                                                     withMethod:@selector(setStateAsNumber:)
                                           withArgumentAsObject:@(LibVLCStateToMediaState(event->u.media_state_changed.new_state))];
    }
}

static void HandleMediaSubItemAdded(const libvlc_event_t * event, void * self)
{
    @autoreleasepool {
        [[VLCEventManager sharedManager] callOnMainThreadObject:(__bridge id)(self)
                                                     withMethod:@selector(subItemAdded)
                                           withArgumentAsObject:nil];
    }
}

static void HandleMediaParsedChanged(const libvlc_event_t * event, void * self)
{
    @autoreleasepool {
        [[VLCEventManager sharedManager] callOnMainThreadObject:(__bridge id)(self)
                                                     withMethod:@selector(parsedChanged:)
                                           withArgumentAsObject:@((BOOL)event->u.media_parsed_changed.new_status)];
    }
}


/******************************************************************************
 * Implementation
 */
@implementation VLCMedia

+ (NSString *)codecNameForFourCC:(uint32_t)fourcc trackType:(NSString *)trackType
{
    libvlc_track_type_t track_type = libvlc_track_unknown;

    if ([trackType isEqualToString:VLCMediaTracksInformationTypeAudio])
        track_type = libvlc_track_audio;
    else if ([trackType isEqualToString:VLCMediaTracksInformationTypeVideo])
        track_type = libvlc_track_video;
    else if ([trackType isEqualToString:VLCMediaTracksInformationTypeText])
        track_type = libvlc_track_text;

    const char *ret = libvlc_media_get_codec_description(track_type, fourcc);
    if (ret)
        return [NSString stringWithUTF8String:ret];

    return @"";
}

+ (instancetype)mediaWithURL:(NSURL *)anURL;
{
    return [[VLCMedia alloc] initWithURL:anURL];
}

+ (instancetype)mediaWithPath:(NSString *)aPath;
{
    return [[VLCMedia alloc] initWithPath:aPath];
}

+ (instancetype)mediaAsNodeWithName:(NSString *)aName;
{
    return [[VLCMedia alloc] initAsNodeWithName:aName];
}

- (instancetype)initWithPath:(NSString *)aPath
{
    return [self initWithURL:[NSURL fileURLWithPath:aPath isDirectory:NO]];
}

- (instancetype)initWithURL:(NSURL *)anURL
{
    if (self = [super init]) {
        const char *url;
        VLCLibrary *library = [VLCLibrary sharedLibrary];
        NSAssert(library.instance, @"no library instance when creating media");

        if (([[anURL absoluteString] hasPrefix:@"sftp://"]) ||
            ([[anURL absoluteString] hasPrefix:@"smb://"])) {
            url = [[[anURL absoluteString] stringByRemovingPercentEncoding] UTF8String];
        } else {
            url = [[anURL absoluteString] UTF8String];
        }

        p_md = libvlc_media_new_location(library.instance, url);

        _metaDictionary = [[NSMutableDictionary alloc] initWithCapacity:3];

        [self initInternalMediaDescriptor];
    }
    return self;
}

- (instancetype)initWithStream:(NSInputStream *)stream
{
    if (self = [super init]) {
        VLCLibrary *library = [VLCLibrary sharedLibrary];
        NSAssert(library.instance, @"no library instance when creating media");
        NSAssert(stream.streamStatus != NSStreamStatusClosed, @"Passing closed stream to VLCMedia.init does not work");
        
        self->stream = stream;
        p_md = libvlc_media_new_callbacks(library.instance, open_cb, read_cb, seek_cb, close_cb, (__bridge void *)(stream));
        
        _metaDictionary = [[NSMutableDictionary alloc] initWithCapacity:3];
        
        [self initInternalMediaDescriptor];
    }
    return self;
}

- (instancetype)initAsNodeWithName:(NSString *)aName
{
    if (self = [super init]) {
        p_md = libvlc_media_new_as_node([VLCLibrary sharedInstance], [aName UTF8String]);

        _metaDictionary = [[NSMutableDictionary alloc] initWithCapacity:3];

        [self initInternalMediaDescriptor];
    }
    return self;
}

- (void)dealloc
{
    libvlc_event_manager_t * p_em = libvlc_media_event_manager(p_md);
    if (p_em) {
        libvlc_event_detach(p_em, libvlc_MediaMetaChanged,     HandleMediaMetaChanged,     (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaDurationChanged, HandleMediaDurationChanged, (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaStateChanged,    HandleMediaStateChanged,    (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaSubItemAdded,    HandleMediaSubItemAdded,    (__bridge void *)(self));
        libvlc_event_detach(p_em, libvlc_MediaParsedChanged,    HandleMediaParsedChanged,   (__bridge void *)(self));
    }

    [[VLCEventManager sharedManager] cancelCallToObject:self];

    libvlc_media_release( p_md );
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

- (NSComparisonResult)compare:(VLCMedia *)media
{
    if (self == media)
        return NSOrderedSame;
    if (!media)
        return NSOrderedDescending;
    return p_md == [media libVLCMediaDescriptor] ? NSOrderedSame : NSOrderedAscending;
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

- (BOOL)isParsed
{
   VLCMediaParsedStatus status = [self parsedStatus];
   return (status == VLCMediaParsedStatusFailed || status == VLCMediaParsedStatusDone) ? YES:NO;
}

- (VLCMediaParsedStatus)parsedStatus
{
    if (!p_md)
        return VLCMediaParsedStatusFailed;
    libvlc_media_parsed_status_t status = libvlc_media_get_parsed_status(p_md);
    return (VLCMediaParsedStatus)status;
}

- (void)parse
{
    if (p_md)
        libvlc_media_parse_async(p_md);
}

- (void)synchronousParse
{
    if (p_md)
        libvlc_media_parse(p_md);
}

- (int)parseWithOptions:(VLCMediaParsingOptions)options timeout:(int)timeoutValue
{
    if (!p_md)
        return -1;

    // we are using the default time-out value
    return libvlc_media_parse_with_options(p_md,
                                           options,
                                           timeoutValue);
}

- (int)parseWithOptions:(VLCMediaParsingOptions)options
{
    if (!p_md)
        return -1;

    // we are using the default time-out value
    return libvlc_media_parse_with_options(p_md,
                                           options,
                                           -1);
}

- (void)addOptions:(NSDictionary*)options
{
    if (p_md) {
        [options enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            if (![obj isKindOfClass:[NSNull class]])
                libvlc_media_add_option(p_md, [[NSString stringWithFormat:@"%@=%@", key, obj] UTF8String]);
            else
                libvlc_media_add_option(p_md, [key UTF8String]);
        }];
    }
}

- (int)storeCookie:(NSString * _Nonnull)cookie
           forHost:(NSString *_Nonnull)host
              path:(NSString *_Nonnull)path
{
    if (!p_md || cookie == NULL || host == NULL || path == NULL) {
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
    if (!p_md) {
        return;
    }

#if TARGET_OS_IPHONE
    libvlc_media_cookie_jar_clear(p_md);
#endif
}

- (NSDictionary *)stats
{
    if (!p_md)
        return nil;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return @{
        @"demuxBitrate" : @(p_stats.f_demux_bitrate),
        @"inputBitrate" : @(p_stats.f_input_bitrate),
        @"sendBitrate" : @(p_stats.f_send_bitrate),
        @"decodedAudio" : @(p_stats.i_decoded_audio),
        @"decodedVideo" : @(p_stats.i_decoded_video),
        @"demuxCorrupted" : @(p_stats.i_demux_corrupted),
        @"demuxDiscontinuity" : @(p_stats.i_demux_discontinuity),
        @"demuxReadBytes" : @(p_stats.i_demux_read_bytes),
        @"displayedPictures" : @(p_stats.i_displayed_pictures),
        @"lostAbuffers" : @(p_stats.i_lost_abuffers),
        @"lostPictures" : @(p_stats.i_lost_pictures),
        @"playedAbuffers" : @(p_stats.i_played_abuffers),
        @"readBytes" : @(p_stats.i_read_bytes),
        @"sentBytes" : @(p_stats.i_sent_bytes),
        @"sentPackets" : @(p_stats.i_sent_packets)
    };
}

- (NSInteger)numberOfReadBytesOnInput
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_read_bytes;
}

- (float)inputBitrate
{
    if (!p_md)
        return .0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.f_input_bitrate;
}

- (NSInteger)numberOfReadBytesOnDemux
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_demux_read_bytes;
}

- (float)demuxBitrate
{
    if (!p_md)
        return .0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.f_demux_bitrate;
}

- (NSInteger)numberOfDecodedVideoBlocks
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_decoded_video;
}

- (NSInteger)numberOfDecodedAudioBlocks
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_decoded_audio;
}

- (NSInteger)numberOfDisplayedPictures
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_displayed_pictures;
}

- (NSInteger)numberOfLostPictures
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_lost_pictures;
}

- (NSInteger)numberOfPlayedAudioBuffers
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_played_abuffers;
}

- (NSInteger)numberOfLostAudioBuffers
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_lost_abuffers;
}

- (NSInteger)numberOfSentPackets
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_sent_packets;
}

- (NSInteger)numberOfSentBytes
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_sent_bytes;
}

- (float)streamOutputBitrate
{
    if (!p_md)
        return .0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.f_send_bitrate;
}

- (NSInteger)numberOfCorruptedDataPackets
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_demux_corrupted;
}

- (NSInteger)numberOfDiscontinuties
{
    if (!p_md)
        return 0;

    libvlc_media_stats_t p_stats;
    libvlc_media_get_stats(p_md, &p_stats);

    return p_stats.i_demux_discontinuity;
}

NSString *const VLCMediaTracksInformationCodec = @"codec"; // NSNumber
NSString *const VLCMediaTracksInformationId    = @"id";    // NSNumber
NSString *const VLCMediaTracksInformationType  = @"type";  // NSString

NSString *const VLCMediaTracksInformationCodecProfile  = @"profile"; // NSNumber
NSString *const VLCMediaTracksInformationCodecLevel    = @"level";   // NSNumber

NSString *const VLCMediaTracksInformationTypeAudio    = @"audio";
NSString *const VLCMediaTracksInformationTypeVideo    = @"video";
NSString *const VLCMediaTracksInformationTypeText     = @"text";
NSString *const VLCMediaTracksInformationTypeUnknown  = @"unknown";

NSString *const VLCMediaTracksInformationBitrate      = @"bitrate"; // NSNumber
NSString *const VLCMediaTracksInformationLanguage     = @"language"; // NSString
NSString *const VLCMediaTracksInformationDescription  = @"description"; // NSString

NSString *const VLCMediaTracksInformationAudioChannelsNumber = @"channelsNumber"; // NSNumber
NSString *const VLCMediaTracksInformationAudioRate           = @"rate";           // NSNumber

NSString *const VLCMediaTracksInformationVideoHeight = @"height"; // NSNumber
NSString *const VLCMediaTracksInformationVideoWidth  = @"width";  // NSNumber
NSString *const VLCMediaTracksInformationVideoOrientation = @"orientation"; // NSNumber
NSString *const VLCMediaTracksInformationVideoProjection = @"projection";   // NSNumber

NSString *const VLCMediaTracksInformationSourceAspectRatio        = @"sar_num"; // NSNumber
NSString *const VLCMediaTracksInformationSourceAspectRatioDenominator  = @"sar_den";  // NSNumber

NSString *const VLCMediaTracksInformationFrameRate             = @"frame_rate_num"; // NSNumber
NSString *const VLCMediaTracksInformationFrameRateDenominator  = @"frame_rate_den";  // NSNumber

NSString *const VLCMediaTracksInformationTextEncoding = @"encoding"; // NSString

- (NSArray *)tracksInformation
{
    libvlc_media_track_t **tracksInfo;
    unsigned int count = libvlc_media_tracks_get(p_md, &tracksInfo);
    NSMutableArray *array = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; i++) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                           @(tracksInfo[i]->i_codec),
                                           VLCMediaTracksInformationCodec,
                                           @(tracksInfo[i]->i_id),
                                           VLCMediaTracksInformationId,
                                           @(tracksInfo[i]->i_profile),
                                           VLCMediaTracksInformationCodecProfile,
                                           @(tracksInfo[i]->i_level),
                                           VLCMediaTracksInformationCodecLevel,
                                           @(tracksInfo[i]->i_bitrate),
                                           VLCMediaTracksInformationBitrate,
                                           nil];
        if (tracksInfo[i]->psz_language)
            dictionary[VLCMediaTracksInformationLanguage] = [NSString stringWithUTF8String:tracksInfo[i]->psz_language];

        if (tracksInfo[i]->psz_description)
            dictionary[VLCMediaTracksInformationDescription] = [NSString stringWithUTF8String:tracksInfo[i]->psz_description];

        NSString *type;
        switch (tracksInfo[i]->i_type) {
            case libvlc_track_audio:
                type = VLCMediaTracksInformationTypeAudio;
                dictionary[VLCMediaTracksInformationAudioChannelsNumber] = @(tracksInfo[i]->audio->i_channels);
                dictionary[VLCMediaTracksInformationAudioRate] = @(tracksInfo[i]->audio->i_rate);
                break;
            case libvlc_track_video:
                type = VLCMediaTracksInformationTypeVideo;
                dictionary[VLCMediaTracksInformationVideoWidth] = @(tracksInfo[i]->video->i_width);
                dictionary[VLCMediaTracksInformationVideoHeight] = @(tracksInfo[i]->video->i_height);
                dictionary[VLCMediaTracksInformationVideoOrientation] = @(tracksInfo[i]->video->i_orientation);
                dictionary[VLCMediaTracksInformationVideoProjection] = @(tracksInfo[i]->video->i_projection);
                dictionary[VLCMediaTracksInformationSourceAspectRatio] = @(tracksInfo[i]->video->i_sar_num);
                dictionary[VLCMediaTracksInformationSourceAspectRatioDenominator] = @(tracksInfo[i]->video->i_sar_den);
                dictionary[VLCMediaTracksInformationFrameRate] = @(tracksInfo[i]->video->i_frame_rate_num);
                dictionary[VLCMediaTracksInformationFrameRateDenominator] = @(tracksInfo[i]->video->i_frame_rate_den);
                break;
            case libvlc_track_text:
                type = VLCMediaTracksInformationTypeText;
                if (tracksInfo[i]->subtitle->psz_encoding)
                    dictionary[VLCMediaTracksInformationTextEncoding] = [NSString stringWithUTF8String: tracksInfo[i]->subtitle->psz_encoding];
                break;
            case libvlc_track_unknown:
            default:
                type = VLCMediaTracksInformationTypeUnknown;
                break;
        }
        [dictionary setValue:type forKey:VLCMediaTracksInformationType];

        [array addObject:dictionary];
    }
    libvlc_media_tracks_release(tracksInfo, count);
    return array;
}

- (BOOL)isMediaSizeSuitableForDevice
{
#if TARGET_OS_IPHONE
    // Trigger parsing if needed
    VLCMediaParsedStatus parsedStatus = [self parsedStatus];
    if (parsedStatus == VLCMediaParsedStatusSkipped || parsedStatus == VLCMediaParsedStatusInit) {
        [self parseWithOptions:VLCMediaParseLocal|VLCMediaParseNetwork];
        sleep(2);
    }

    NSUInteger biggestWidth = 0;
    NSUInteger biggestHeight = 0;
    libvlc_media_track_t **tracksInfo;
    unsigned int count = libvlc_media_tracks_get(p_md, &tracksInfo);
    for (NSUInteger i = 0; i < count; i++) {
        switch (tracksInfo[i]->i_type) {
            case libvlc_track_video:
                if (tracksInfo[i]->video->i_width > biggestWidth)
                    biggestWidth = tracksInfo[i]->video->i_width;
                if (tracksInfo[i]->video->i_height > biggestHeight)
                    biggestHeight = tracksInfo[i]->video->i_height;
                break;
            default:
                break;
        }
    }

    if (biggestHeight > 0 && biggestWidth > 0) {
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);

        char *answer = malloc(size);
        sysctlbyname("hw.machine", answer, &size, NULL, 0);

        NSString *currentMachine = @(answer);
        free(answer);

        NSUInteger totalNumberOfPixels = biggestWidth * biggestHeight;

        if ([currentMachine hasPrefix:@"iPhone2"] || [currentMachine hasPrefix:@"iPhone3"] || [currentMachine hasPrefix:@"iPad1"] || [currentMachine hasPrefix:@"iPod3"] || [currentMachine hasPrefix:@"iPod4"]) {
            // iPhone 3GS, iPhone 4, first gen. iPad, 3rd and 4th generation iPod touch
            return (totalNumberOfPixels < 600000); // between 480p and 720p
        } else if ([currentMachine hasPrefix:@"iPhone4"] || [currentMachine hasPrefix:@"iPad3,1"] || [currentMachine hasPrefix:@"iPad3,2"] || [currentMachine hasPrefix:@"iPad3,3"] || [currentMachine hasPrefix:@"iPod4"] || [currentMachine hasPrefix:@"iPad2"] || [currentMachine hasPrefix:@"iPod5"]) {
            // iPhone 4S, iPad 2 and 3, iPod 4 and 5
            return (totalNumberOfPixels < 922000); // 720p
        } else {
            // iPhone 5, iPad 4
            return (totalNumberOfPixels < 2074000); // 1080p
        }
    }
#endif

    return YES;
}

- (NSString *)metadataForKey:(NSString *)key
{
    if (!p_md)
        return nil;

    char *returnValue = libvlc_media_get_meta(p_md, [VLCMedia stringToMetaType:key]);

    if (!returnValue)
        return nil;

    NSString *actualReturnValue = @(returnValue);
    free(returnValue);

    return actualReturnValue;
}

- (void)setMetadata:(NSString *)data forKey:(NSString *)key
{
    if (!p_md)
        return;

    libvlc_media_set_meta(p_md, [VLCMedia stringToMetaType:key], [data UTF8String]);
}

- (BOOL)saveMetadata
{
    if (p_md)
        return libvlc_media_save_meta(p_md) != 0;

    return NO;
}

/******************************************************************************
 * Implementation VLCMedia ()
 */

+ (libvlc_meta_t)stringToMetaType:(NSString *)string
{
    static NSDictionary * stringToMetaDictionary = nil;
    // TODO: Thread safe-ize
    if (!stringToMetaDictionary) {
#define VLCStringToMeta( name ) [NSNumber numberWithInt: libvlc_meta_##name], VLCMetaInformation##name
        stringToMetaDictionary =
            [NSDictionary dictionaryWithObjectsAndKeys:
                VLCStringToMeta(Title),
                VLCStringToMeta(Artist),
                VLCStringToMeta(Genre),
                VLCStringToMeta(Copyright),
                VLCStringToMeta(Album),
                VLCStringToMeta(TrackNumber),
                VLCStringToMeta(Description),
                VLCStringToMeta(Rating),
                VLCStringToMeta(Date),
                VLCStringToMeta(Setting),
                VLCStringToMeta(URL),
                VLCStringToMeta(Language),
                VLCStringToMeta(NowPlaying),
                VLCStringToMeta(Publisher),
                VLCStringToMeta(ArtworkURL),
                VLCStringToMeta(TrackID),
                VLCStringToMeta(TrackTotal),
                VLCStringToMeta(Director),
                VLCStringToMeta(Season),
                VLCStringToMeta(Episode),
                VLCStringToMeta(ShowName),
                VLCStringToMeta(Actors),
                VLCStringToMeta(AlbumArtist),
                VLCStringToMeta(DiscNumber),
                nil];
#undef VLCStringToMeta
    }
    NSNumber * number = stringToMetaDictionary[string];
    return (libvlc_meta_t) (number ? [number intValue] : -1);
}

+ (NSString *)metaTypeToString:(libvlc_meta_t)type
{
#define VLCMetaToString( name, type )   if (libvlc_meta_##name == type) return VLCMetaInformation##name;
    VLCMetaToString(Title, type);
    VLCMetaToString(Artist, type);
    VLCMetaToString(Genre, type);
    VLCMetaToString(Copyright, type);
    VLCMetaToString(Album, type);
    VLCMetaToString(TrackNumber, type);
    VLCMetaToString(Description, type);
    VLCMetaToString(Rating, type);
    VLCMetaToString(Date, type);
    VLCMetaToString(Setting, type);
    VLCMetaToString(URL, type);
    VLCMetaToString(Language, type);
    VLCMetaToString(NowPlaying, type);
    VLCMetaToString(Publisher, type);
    VLCMetaToString(ArtworkURL, type);
    VLCMetaToString(TrackID, type);
    VLCMetaToString(TrackTotal, type);
    VLCMetaToString(Director, type);
    VLCMetaToString(Season, type);
    VLCMetaToString(Episode, type);
    VLCMetaToString(ShowName, type);
    VLCMetaToString(Actors, type);
    VLCMetaToString(AlbumArtist, type);
    VLCMetaToString(DiscNumber, type);
#undef VLCMetaToString
    return nil;
}

- (void)initInternalMediaDescriptor
{
    char * p_url = libvlc_media_get_mrl( p_md );
    if (!p_url)
        return;

    NSString *urlString = [NSString stringWithUTF8String:p_url];
    if (!urlString) {
        free(p_url);
        return;
    }

    urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    if (!urlString) {
        free(p_url);
        return;
    }

    _url = [NSURL URLWithString:urlString];
    if (!_url) /* Attempt to interpret as a file path then */ {
         _url = [NSURL fileURLWithPath:urlString];
         if(!_url) {
             free(p_url);
             return;
         }
    }
    free(p_url);

    libvlc_media_set_user_data(p_md, (__bridge void*)self);

    libvlc_event_manager_t * p_em = libvlc_media_event_manager( p_md );
    if (p_em) {
        libvlc_event_attach(p_em, libvlc_MediaMetaChanged,     HandleMediaMetaChanged,     (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaDurationChanged, HandleMediaDurationChanged, (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaStateChanged,    HandleMediaStateChanged,    (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaSubItemAdded,    HandleMediaSubItemAdded,    (__bridge void *)(self));
        libvlc_event_attach(p_em, libvlc_MediaParsedChanged,    HandleMediaParsedChanged,   (__bridge void *)(self));
    }

    libvlc_media_list_t * p_mlist = libvlc_media_subitems( p_md );

    if (p_mlist) {
        self.subitems = [VLCMediaList mediaListWithLibVLCMediaList:p_mlist];
        libvlc_media_list_release( p_mlist );
    }

    self.state = LibVLCStateToMediaState(libvlc_media_get_state( p_md ));
}

- (void)fetchMetaInformationFromLibVLCWithType:(NSString *)metaType
{
    char * psz_value = libvlc_media_get_meta( p_md, [VLCMedia stringToMetaType:metaType] );
    NSString * newValue = psz_value ? @(psz_value) : nil;
    NSString * oldValue = [_metaDictionary valueForKey:metaType];
    free(psz_value);

    if (newValue != oldValue && !(oldValue && newValue && [oldValue compare:newValue] == NSOrderedSame)) {
#if !TARGET_OS_IPHONE
        // Only fetch the art if needed. (ie, create the NSImage, if it was requested before)
        if (isArtFetched && [metaType isEqualToString:VLCMetaInformationArtworkURL]) {
            [NSThread detachNewThreadSelector:@selector(fetchMetaInformationForArtWorkWithURL:)
                                         toTarget:self
                                       withObject:newValue];
        }
#endif

        [_metaDictionary setValue:newValue forKeyPath:metaType];
    }
}

#if !TARGET_OS_IPHONE
- (void)fetchMetaInformationForArtWorkWithURL:(NSString *)anURL
{
    @autoreleasepool {
        NSImage * art = nil;

        if (anURL) {
            // Go ahead and load up the art work
            NSURL * artUrl = [NSURL URLWithString:[anURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            // Don't attempt to fetch artwork from remote. Core will do that alone
            if ([artUrl isFileURL])
                art  = [[NSImage alloc] initWithContentsOfURL:artUrl];
        }

        // If anything was found, lets save it to the meta data dictionary
        [self performSelectorOnMainThread:@selector(setArtwork:) withObject:art waitUntilDone:NO];
    }
}

- (void)setArtwork:(NSImage *)art
{
    if (!art)
        [(NSMutableDictionary *)_metaDictionary removeObjectForKey:@"artwork"];
    else
        ((NSMutableDictionary *)_metaDictionary)[@"artwork"] = art;
}
#endif

- (void)parseIfNeeded
{
    VLCMediaParsedStatus parsedStatus = [self parsedStatus];
    if (parsedStatus == VLCMediaParsedStatusSkipped || parsedStatus == VLCMediaParsedStatusInit)
        [self parseWithOptions:VLCMediaParseLocal | VLCMediaFetchLocal];
}

- (void)metaChanged:(NSString *)metaType
{
    [self fetchMetaInformationFromLibVLCWithType:metaType];

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

- (void)parsedChanged:(NSNumber *)isParsedAsNumber
{
    [self willChangeValueForKey:@"parsedStatus"];
    [self parsedStatus];
    [self didChangeValueForKey:@"parsedStatus"];

    if (!_delegate)
        return;

    if ([_delegate respondsToSelector:@selector(mediaDidFinishParsing:)])
        [_delegate mediaDidFinishParsing:self];
}

- (void)setStateAsNumber:(NSNumber *)newStateAsNumber
{
    [self setState: [newStateAsNumber intValue]];
}

#if TARGET_OS_IPHONE
- (NSDictionary *)metaDictionary
{
    if (!areOthersMetaFetched) {
        areOthersMetaFetched = YES;

        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationTitle];
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationArtist];
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationAlbum];
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationDate];
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationGenre];
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationTrackNumber];
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationDiscNumber];
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationNowPlaying];
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationLanguage];
    }
    if (!isArtURLFetched) {
        isArtURLFetched = YES;
        /* Force isArtURLFetched, that will trigger artwork download eventually
         * And all the other meta will be added through the libvlc event system */
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationArtworkURL];
    }
    return [NSDictionary dictionaryWithDictionary:_metaDictionary];
}

#else

- (NSDictionary *)metaDictionary
{
    return [NSDictionary dictionaryWithDictionary:_metaDictionary];
}

- (id)valueForKeyPath:(NSString *)keyPath
{
    if (!isArtFetched && [keyPath isEqualToString:@"metaDictionary.artwork"]) {
        isArtFetched = YES;
        /* Force the retrieval of the artwork now that someone asked for it */
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationArtworkURL];
    } else if (!areOthersMetaFetched && [keyPath hasPrefix:@"metaDictionary."]) {
        areOthersMetaFetched = YES;
        /* Force VLCMetaInformationTitle, that will trigger preparsing
         * And all the other meta will be added through the libvlc event system */
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationTitle];
    } else if (!isArtURLFetched && [keyPath hasPrefix:@"metaDictionary.artworkURL"]) {
        isArtURLFetched = YES;
        /* Force isArtURLFetched, that will trigger artwork download eventually
         * And all the other meta will be added through the libvlc event system */
        [self fetchMetaInformationFromLibVLCWithType: VLCMetaInformationArtworkURL];
    }
    return [super valueForKeyPath:keyPath];
}
#endif
@end

/******************************************************************************
 * Implementation VLCMedia (LibVLCBridging)
 */
@implementation VLCMedia (LibVLCBridging)

+ (id)mediaWithLibVLCMediaDescriptor:(void *)md
{
    return [[VLCMedia alloc] initWithLibVLCMediaDescriptor:md];
}

+ (id)mediaWithMedia:(VLCMedia *)media andLibVLCOptions:(NSDictionary *)options
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

- (id)initWithLibVLCMediaDescriptor:(void *)md
{
    if (self = [super init]) {
        libvlc_media_retain(md);
        p_md = md;

        _metaDictionary = [[NSMutableDictionary alloc] initWithCapacity:3];

        [self initInternalMediaDescriptor];
    }
    return self;
}

- (void *)libVLCMediaDescriptor
{
    return p_md;
}


@end
