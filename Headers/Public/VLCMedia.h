/*****************************************************************************
 * VLCMedia.h: VLCKit.framework VLCMedia header
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2013 Felix Paul Kühne
 * Copyright (C) 2007-2013 VLC authors and VideoLAN
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

#import <Foundation/Foundation.h>

@class VLCTime, VLCMediaTrack, VLCMediaMetaData;

NS_ASSUME_NONNULL_BEGIN

/* Notification Messages */
/**
 * Available notification messages.
 */
OBJC_VISIBLE OBJC_EXTERN
NSString *const VLCMediaMetaChanged;  ///< Notification message for when the media's meta data has changed

// Forward declarations, supresses compiler error messages
@class VLCMediaList;
@class VLCMedia;

/**
 * Informal protocol declaration for VLCMedia delegates.  Allows data changes to be
 * trapped.
 */
@protocol VLCMediaDelegate <NSObject>

@optional

/**
 * Delegate method called whenever the media's meta data was changed for whatever reason
 * \note this is called more often than mediaDidFinishParsing, so it may be less efficient
 * \param aMedia The media resource whose meta data has been changed.
 */
- (void)mediaMetaDataDidChange:(VLCMedia *)aMedia;

/**
 * Delegate method called whenever the media was parsed.
 * \param aMedia The media resource whose meta data has been changed.
 */

- (void)mediaDidFinishParsing:(VLCMedia *)aMedia;
@end

/**
 * Defines files and streams as a managed object.  Each media object can be
 * administered seperately.  VLCMediaPlayer or VLCMediaList must be used
 * to execute the appropriate playback functions.
 * \see VLCMediaPlayer
 * \see VLCMediaList
 */
OBJC_VISIBLE
@interface VLCMedia : NSObject

/* Factories */
/**
 * Manufactures a new VLCMedia object using the URL specified.
 * \param anURL URL to media to be accessed.
 * \return A new VLCMedia object, only if there were no errors.  This object will be automatically released.
 * \see initWithMediaURL
 */
+ (instancetype)mediaWithURL:(NSURL *)anURL;

/**
 * Manufactures a new VLCMedia object using the path specified.
 * \param aPath Path to the media to be accessed.
 * \return A new VLCMedia object, only if there were no errors.  This object will be automatically released.
 * \see initWithPath
 */
+ (instancetype)mediaWithPath:(NSString *)aPath;

/**
 * list of possible track information type.
 */

typedef NS_ENUM(NSInteger, VLCMediaTrackType) {
    VLCMediaTrackTypeUnknown    = -1,
    VLCMediaTrackTypeAudio      = 0,
    VLCMediaTrackTypeVideo      = 1,
    VLCMediaTrackTypeText       = 2
} NS_SWIFT_NAME(VLCMedia.TrackType);

/**
 * convienience method to return a user-readable codec name for the given FourCC
 * \param fourcc the FourCC to process
 * \param trackType a VLC track type if known to speed-up the name search
 * \return a NSString containing the codec name if recognized, else an empty string
 */
+ (NSString *)codecNameForFourCC:(uint32_t)fourcc trackType:(VLCMediaTrackType)trackType;

/**
 * TODO
 * \param aName TODO
 * \return a new VLCMedia object, only if there were no errors.  This object
 * will be automatically released.
 * \see initAsNodeWithName
 */
+ (instancetype)mediaAsNodeWithName:(NSString *)aName;

/* Initializers */
/**
 * Initializes a new VLCMedia object to use the specified URL.
 * \param anURL the URL to media to be accessed.
 * \return A new VLCMedia object, only if there were no errors.
 */
- (instancetype)initWithURL:(NSURL *)anURL;

/**
 * Initializes a new VLCMedia object to use the specified path.
 * \param aPath Path to media to be accessed.
 * \return A new VLCMedia object, only if there were no errors.
 */
- (instancetype)initWithPath:(NSString *)aPath;

/**
 * Initializes a new VLCMedia object to use an input stream.
 *
 * \note By default, NSStream instances that are not file-based are non-seekable,
 * you may subclass NSInputStream whose instances are capable of seeking through a stream.
 * This subclass must allow setting NSStreamFileCurrentOffsetKey property.
 * \note VLCMedia will open stream if it is not already opened, and will close eventually.
 * You can't pass an already closed input stream.
 * \param stream Input stream for media to be accessed.
 * \return A new VLCMedia object, only if there were no errors.
 */
- (instancetype)initWithStream:(NSInputStream *)stream;

/**
 * TODO
 * \param aName TODO
 * \return A new VLCMedia object, only if there were no errors.
 */
- (instancetype)initAsNodeWithName:(NSString *)aName;

/**
 * list of possible media orientation.
 */
typedef NS_ENUM(NSUInteger, VLCMediaOrientation) {
    VLCMediaOrientationTopLeft,
    VLCMediaOrientationTopRight,
    VLCMediaOrientationBottomLeft,
    VLCMediaOrientationBottomRight,
    VLCMediaOrientationLeftTop,
    VLCMediaOrientationLeftBottom,
    VLCMediaOrientationRightTop,
    VLCMediaOrientationRightBottom
};

/**
 * list of possible media projection.
 */
typedef NS_ENUM(NSUInteger, VLCMediaProjection) {
    VLCMediaProjectionRectangular,
    VLCMediaProjectionEquiRectangular,
    VLCMediaProjectionCubemapLayoutStandard = 0x100
};

/**
 * list of possible media types that could be returned by "mediaType"
 */
typedef NS_ENUM(NSUInteger, VLCMediaType) {
    VLCMediaTypeUnknown,
    VLCMediaTypeFile,
    VLCMediaTypeDirectory,
    VLCMediaTypeDisc,
    VLCMediaTypeStream,
    VLCMediaTypePlaylist,
};

/**
 * media type
 * \return returns the type of a media (VLCMediaType)
 */
@property (readonly) VLCMediaType mediaType;

/**
 * Returns an NSComparisonResult value that indicates the lexical ordering of
 * the receiver and a given meda.
 * \param media The media with which to compare with the receiver.
 * \return NSOrderedAscending if the URL of the receiver precedes media in
 * lexical ordering, NSOrderedSame if the URL of the receiver and media are
 * equivalent in lexical value, and NSOrderedDescending if the URL of the
 * receiver follows media. If media is nil, returns NSOrderedDescending.
 */
- (NSComparisonResult)compare:(nullable VLCMedia *)media;

/* Properties */
/**
 * Receiver's delegate.
 */
@property (nonatomic, weak, nullable) id<VLCMediaDelegate> delegate;

/**
 * A VLCTime object describing the length of the media resource, only if it is
 * available.  Use lengthWaitUntilDate: to wait for a specified length of time.
 * \see lengthWaitUntilDate
 */
@property (nonatomic, readwrite, strong) VLCTime * length;

/**
 * Returns a VLCTime object describing the length of the media resource,
 * however, this is a blocking operation and will wait until the preparsing is
 * completed before returning anything.
 * \param aDate Time for operation to wait until, if there are no results
 * before specified date then nil is returned.
 * \return The length of the media resource, nil if it couldn't wait for it.
 */
- (VLCTime *)lengthWaitUntilDate:(NSDate *)aDate;

/**
 * list of possible parsed states returnable by parsedStatus
 */
typedef NS_ENUM(unsigned, VLCMediaParsedStatus)
{
    VLCMediaParsedStatusInit = 0,
    VLCMediaParsedStatusSkipped,
    VLCMediaParsedStatusFailed,
    VLCMediaParsedStatusTimeout,
    VLCMediaParsedStatusDone
};
/**
 * \return Returns the parse status of the media
 */
@property (nonatomic, readonly) VLCMediaParsedStatus parsedStatus;

/**
 * The URL for the receiver's media resource.
 */
@property (nonatomic, readonly, strong, nullable) NSURL * url;

/**
 * The receiver's sub list.
 */
@property (nonatomic, readonly, strong, nullable) VLCMediaList * subitems;

/**
 * meta data
 */
@property (nonatomic, readonly) VLCMediaMetaData *metaData;

/**
 * returns a bool whether is the media is expected to play fluently on this
 * device or not. It always returns YES on a Mac.*/
@property (NS_NONATOMIC_IOSONLY, getter=isMediaSizeSuitableForDevice, readonly) BOOL mediaSizeSuitableForDevice;

/**
 * Returns the tracks information.
 */
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray<VLCMediaTrack *> *tracksInformation;

/**
 * list of possible libvlc_media_filestat type.
 */
typedef NS_ENUM(unsigned, VLCMediaFileStatType) {
    VLCMediaFileStatTypeMtime   = 0,
    VLCMediaFileStatTypeSize    = 1
} NS_SWIFT_NAME(VLCMedia.FileStatType);

/**
 * list of possible libvlc_media_filestat return type.
 */
typedef NS_ENUM(int, VLCMediaFileStatReturnType) {
    VLCMediaFileStatReturnTypeError     = -1,
    VLCMediaFileStatReturnTypeNotFound  = 0,
    VLCMediaFileStatReturnTypeSuccess   = 1
} NS_SWIFT_NAME(VLCMedia.FileStatReturnType);

/**
 * Get a 'filestat' value
 *
 * 'stat' values are currently only parsed by directory accesses. This mean that only sub medias of a directory media,
 * parsed with libvlc_media_parse_with_options() can have valid 'stat' properties.
 * \param type VLCMediaFileStatType
 * \param value field in which the value will be stored
 * \return VLCMediaFileStatReturnType
 */
- (VLCMediaFileStatReturnType)fileStatValueForType:(const VLCMediaFileStatType)type value:(uint64_t *)value;

/**
 * enum of available options for use with parseWithOptions
 * \note you may pipe multiple values for the single parameter
 */
typedef NS_OPTIONS(int, VLCMediaParsingOptions) {
    VLCMediaParseLocal          = 0x00,     ///< Parse media if it's a local file
    VLCMediaParseNetwork        = 0x01,     ///< Parse media even if it's a network file
    VLCMediaFetchLocal          = 0x02,     ///< Fetch meta and covert art using local resources
    VLCMediaFetchNetwork        = 0x04,     ///< Fetch meta and covert art using network resources
    VLCMediaDoInteract          = 0x08,     ///< Interact with the user when preparsing this item (and not its sub items). Set this flag in order to receive a callback when the input is asking for credentials.
};

/**
 * triggers an asynchronous parse of the media item
 * using the given options
 * \param options the option mask based on VLCMediaParsingOptions
 * \see VLCMediaParsingOptions
 * \return an int. 0 on success, -1 in case of error
 * \note listen to the "parsed" key value or the mediaDidFinishParsing:
 * delegate method to be notified about parsing results. Those triggers
 * will _NOT_ be raised if parsing fails and this method returns an error.
 */
- (int)parseWithOptions:(VLCMediaParsingOptions)options;

/**
 * triggers an asynchronous parse of the media item
 * using the given options
 * \param options the option mask based on VLCMediaParsingOptions
 * \param timeoutValue a time-out value in milliseconds (-1 for default, 0 for infinite)
 * \see VLCMediaParsingOptions
 * \return an int. 0 on success, -1 in case of error
 * \note listen to the "parsed" key value or the mediaDidFinishParsing:
 * delegate method to be notified about parsing results. Those triggers
 * will _NOT_ be raised if parsing fails and this method returns an error.
 */
- (int)parseWithOptions:(VLCMediaParsingOptions)options timeout:(int)timeoutValue;

/**
 * Stop the parsing of the media
 *
 * When the media parsing is stopped, the mediaDidFinishParsing will
 * be sent with the VLCMediaParsedStatusTimeout status.
*/
- (void)parseStop;

/**
 * Add options to the media, that will be used to determine how
 * VLCMediaPlayer will read the media. This allow to use VLC advanced
 * reading/streaming options in a per-media basis
 *
 * The options are detailed in vlc --long-help, for instance "--sout-all"
 * And on the web: http://wiki.videolan.org/VLC_command-line_help
*/
- (void)addOption:(NSString *)option;
- (void)addOptions:(NSDictionary*)options;

/**
 * Parse a value of an incoming Set-Cookie header (see RFC 6265) and append the
 * cookie to the stored cookies if appropriate. The "secure" attribute can be added
 * to cookie to limit the scope of the cookie to secured channels (https).
 *
 * \note must be called before the first call of play() to
 * take effect. The cookie storage is only used for http/https.
 * \warning This method will never succeed on macOS, but requires iOS or tvOS
 *
 * \param cookie header field value of Set-Cookie: "name=value<;attributes>"
 * \param host host to which the cookie will be sent
 * \param path scope of the cookie
 *
 * \return 0 on success, -1 on error.
 */
- (int)storeCookie:(NSString *)cookie
           forHost:(NSString *)host
              path:(NSString *)path;

/**
 * Clear the stored cookies of a media.
 *
 * \note must be called before the first call of play() to
 * take effect. The cookie jar is only used for http/https.
 * \warning This method will never succeed on macOS, but requires iOS or tvOS
 */
- (void)clearStoredCookies;

/**
 * Getter for statistics information
 * Returns a NSDictionary with NSNumbers for values.
 *
 */
@property (NS_NONATOMIC_IOSONLY, readonly, copy, nullable) NSDictionary *stats;

#pragma mark - individual stats

/**
 * returns the number of bytes read by the current input module
 * \return a NSInteger with the raw number of bytes
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfReadBytesOnInput;
/**
 * returns the current input bitrate. may be 0 if the buffer is full
 * \return a float of the current input bitrate
 */
@property (NS_NONATOMIC_IOSONLY, readonly) float inputBitrate;

/**
 * returns the number of bytes read by the current demux module
 * \return a NSInteger with the raw number of bytes
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfReadBytesOnDemux;
/**
 * returns the current demux bitrate. may be 0 if the buffer is empty
 * \return a float of the current demux bitrate
 */
@property (NS_NONATOMIC_IOSONLY, readonly) float demuxBitrate;

/**
 * returns the total number of decoded video blocks in the current media session
 * \return a NSInteger with the total number of decoded blocks
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfDecodedVideoBlocks;
/**
 * returns the total number of decoded audio blocks in the current media session
 * \return a NSInteger with the total number of decoded blocks
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfDecodedAudioBlocks;

/**
 * returns the total number of displayed pictures during the current media session
 * \return a NSInteger with the total number of displayed pictures
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfDisplayedPictures;
/**
 * returns the total number of pictures lost during the current media session
 * \return a NSInteger with the total number of lost pictures
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfLostPictures;
/**
 * returns the total number of pictures late during the current media session
 * \return a NSInteger with the total number of late pictures
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfLatePictures;

/**
 * returns the total number of played audio buffers during the current media session
 * \return a NSInteger with the total number of played audio buffers
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfPlayedAudioBuffers;
/**
 * returns the total number of audio buffers lost during the current media session
 * \return a NSInteger with the total number of displayed pictures
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfLostAudioBuffers;

/**
 * returns the total number of corrupted data packets during current sout session
 * \note value is 0 on non-stream-output operations
 * \return a NSInteger with the total number of corrupted data packets
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfCorruptedDataPackets;
/**
 * returns the total number of discontinuties during current sout session
 * \note value is 0 on non-stream-output operations
 * \return a NSInteger with the total number of discontinuties
 */
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger numberOfDiscontinuties;

@end


#pragma mark - VLCMediaTrack

/**
 * VLCMediaAudioTrack
 */
NS_SWIFT_NAME(VLCMedia.AudioTrack)
@interface VLCMediaAudioTrack : NSObject

/**
 * number of audio channels of a given track
 */
@property(nonatomic, readonly) unsigned channelsNumber;

/**
 * audio rate
 */
@property(nonatomic, readonly) unsigned rate;


+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end


/**
 * VLCMediaVideoTrack
 */
NS_SWIFT_NAME(VLCMedia.VideoTrack)
@interface VLCMediaVideoTrack : NSObject

/**
 * video track height
 */
@property(nonatomic, readonly) unsigned height;

/**
 * video track width
 */
@property(nonatomic, readonly) unsigned width;

/**
 * video track orientation
 */
@property(nonatomic, readonly) VLCMediaOrientation orientation;

/**
 * video track projection
 */
@property(nonatomic, readonly) VLCMediaProjection projection;

/**
 * source aspect ratio
 */
@property(nonatomic, readonly) unsigned sourceAspectRatio;

/**
 * source aspect ratio denominator
 */
@property(nonatomic, readonly) unsigned sourceAspectRatioDenominator;

/**
 * frame rate
 */
@property(nonatomic, readonly) unsigned frameRate;

/**
 * frame rate denominator
 */
@property(nonatomic, readonly) unsigned frameRateDenominator;


+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end


/**
 * VLCMediaTextTrack
 */
NS_SWIFT_NAME(VLCMedia.TextTrack)
@interface VLCMediaTextTrack : NSObject

/**
 * text encoding
 */
@property(nonatomic, readonly, copy, nullable) NSString *encoding;


+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end


/**
 * VLCMediaTrack
 */
NS_SWIFT_NAME(VLCMedia.Track)
@interface VLCMediaTrack : NSObject

/**
 * track information type
 */
@property(nonatomic, readonly) VLCMediaTrackType type;

/**
 * codec information
 */
@property(nonatomic, readonly) u_int32_t codec;

/**
 * codec fourcc
 */
@property(nonatomic, readonly) u_int32_t fourcc;

/**
 * tracks information ID
 */
@property(nonatomic, readonly) int identifier;

/**
 * codec profile
 */
@property(nonatomic, readonly) int profile;

/**
 * codec level
 */
@property(nonatomic, readonly) int level;

/**
 * track bitrate
 */
@property(nonatomic, readonly) unsigned int bitrate;

/**
 * track language
 */
@property(nonatomic, readonly, copy, nullable) NSString *language;

/**
 * track description
 */
@property(nonatomic, readonly, copy, nullable) NSString *trackDescription;

/**
 * VLCMediaAudioTrack
 */
@property(nonatomic, readonly, nullable) VLCMediaAudioTrack *audio;

/**
 * VLCMediaVideoTrack
 */
@property(nonatomic, readonly, nullable) VLCMediaVideoTrack *video;

/**
 * VLCMediaTextTrack
 */
@property(nonatomic, readonly, nullable) VLCMediaTextTrack *text;

/**
 * user readable codec name
 *
 * \return codec name or empty string
 */
- (NSString *)codecName;


+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

/**
 * VLCMediaPlayerTrack
 */
NS_SWIFT_NAME(VLCMediaPlayer.Track)
@interface VLCMediaPlayerTrack : VLCMediaTrack

/**
 * String identifier of track
 */
@property (nonatomic, readonly, copy) NSString *trackId;

/**
 * A string identifier is stable when it is certified to be the same
 * across different playback instances for the same track
 */
@property (nonatomic, readonly, getter=isIdStable) BOOL idStable;

/**
 * Name of the track
 */
@property (nonatomic, readonly, copy) NSString *trackName;

/**
 * true if the track is selected
 */
@property (nonatomic, getter=isSelected) BOOL selected;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
