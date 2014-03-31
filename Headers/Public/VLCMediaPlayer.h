/*****************************************************************************
 * VLCMediaPlayer.h: VLCKit.framework VLCMediaPlayer header
 *****************************************************************************
 * Copyright (C) 2007-2009 Pierre d'Herbemont
 * Copyright (C) 2007-2014 VLC authors and VideoLAN
 * Copyright (C) 2009-2014 Felix Paul Kühne
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

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
# import <CoreGraphics/CoreGraphics.h>
#endif
#import "VLCMedia.h"
#import "VLCTime.h"
#import "VLCAudio.h"

#if !TARGET_OS_IPHONE
@class VLCVideoView;
@class VLCVideoLayer;
#endif

@class VLCLibrary;

/* Notification Messages */
extern NSString *const VLCMediaPlayerTimeChanged;
extern NSString *const VLCMediaPlayerStateChanged;

/**
 * VLCMediaPlayerState describes the state of the media player.
 */
enum
{
    VLCMediaPlayerStateStopped,        //< Player has stopped
    VLCMediaPlayerStateOpening,        //< Stream is opening
    VLCMediaPlayerStateBuffering,      //< Stream is buffering
    VLCMediaPlayerStateEnded,          //< Stream has ended
    VLCMediaPlayerStateError,          //< Player has generated an error
    VLCMediaPlayerStatePlaying,        //< Stream is playing
    VLCMediaPlayerStatePaused          //< Stream is paused
};
typedef NSInteger VLCMediaPlayerState;

/**
 * Returns the name of the player state as a string.
 * \param state The player state.
 * \return A string containing the name of state. If state is not a valid state, returns nil.
 */
extern NSString * VLCMediaPlayerStateToString(VLCMediaPlayerState state);

/**
 * Formal protocol declaration for playback delegates.  Allows playback messages
 * to be trapped by delegated objects.
 */
@protocol VLCMediaPlayerDelegate

@optional
/**
 * Sent by the default notification center whenever the player's state has changed.
 * \details Discussion The value of aNotification is always an VLCMediaPlayerStateChanged notification. You can retrieve
 * the VLCMediaPlayer object in question by sending object to aNotification.
 */
- (void)mediaPlayerStateChanged:(NSNotification *)aNotification;

/**
 * Sent by the default notification center whenever the player's time has changed.
 * \details Discussion The value of aNotification is always an VLCMediaPlayerTimeChanged notification. You can retrieve
 * the VLCMediaPlayer object in question by sending object to aNotification.
 */
- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification;

@end


// TODO: Should we use medialist_player or our own flavor of media player?
@interface VLCMediaPlayer : NSObject

@property (readonly) VLCLibrary *libraryInstance;

#if !TARGET_OS_IPHONE
/* Initializers */
- (id)initWithVideoView:(VLCVideoView *)aVideoView;
- (id)initWithVideoLayer:(VLCVideoLayer *)aVideoLayer;
#endif
- (id)initWithOptions:(NSArray *)options;

/* Properties */
- (void)setDelegate:(id)value;
- (id)delegate;

/* Video View Options */
// TODO: Should be it's own object?

#pragma mark -
#pragma mark video functionality

#if !TARGET_OS_IPHONE
- (void)setVideoView:(VLCVideoView *)aVideoView;
- (void)setVideoLayer:(VLCVideoLayer *)aVideoLayer;
#endif

@property (retain) id drawable; /* The videoView or videoLayer */

/**
 * Set/Get current video aspect ratio.
 *
 * \param psz_aspect new video aspect-ratio or NULL to reset to default
 * \note Invalid aspect ratios are ignored.
 * \return the video aspect ratio or NULL if unspecified
 * (the result must be released with free()).
 */
- (void)setVideoAspectRatio:(char *)value;
- (char *)videoAspectRatio;

/**
 * Set/Get current crop filter geometry.
 *
 * \param psz_geometry new crop filter geometry (NULL to unset)
 * \return the crop filter geometry or NULL if unset
 */
- (void)setVideoCropGeometry:(char *)value;
- (char *)videoCropGeometry;

/**
 * Set/Get the current video scaling factor.
 * That is the ratio of the number of pixels on
 * screen to the number of pixels in the original decoded video in each
 * dimension. Zero is a special value; it will adjust the video to the output
 * window/drawable (in windowed mode) or the entire screen.
 *
 * \param relative scale factor as float
 */
@property (readwrite) float scaleFactor;

/**
 * Take a snapshot of the current video.
 *
 * If width AND height is 0, original size is used.
 * If width OR height is 0, original aspect-ratio is preserved.
 *
 * \param path the path where to save the screenshot to
 * \param width the snapshot's width
 * \param height the snapshot's height
 */
- (void)saveVideoSnapshotAt: (NSString *)path withWidth:(int)width andHeight:(int)height;

/**
 * Enable or disable deinterlace filter
 *
 * \param name of deinterlace filter to use (availability depends on underlying VLC version), NULL to disable.
 */
- (void)setDeinterlaceFilter: (NSString *)name;

/**
 * Enable or disable adjust video filter (contrast, brightness, hue, saturation, gamma)
 *
 * \param bool value
 */
@property BOOL adjustFilterEnabled;
/**
 * Set/Get the adjust filter's contrast value
 *
 * \param float value (range: 0-2, default: 1.0)
 */
@property float contrast;
/**
 * Set/Get the adjust filter's brightness value
 *
 * \param float value (range: 0-2, default: 1.0)
 */
@property float brightness;
/**
 * Set/Get the adjust filter's hue value
 *
 * \param integer value (range: 0-360, default: 0)
 */
@property int hue;
/**
 * Set/Get the adjust filter's saturation value
 *
 * \param float value (range: 0-3, default: 1.0)
 */
@property float saturation;
/**
 * Set/Get the adjust filter's gamma value
 *
 * \param float value (range: 0-10, default: 1.0)
 */
@property float gamma;

/**
 * Get the requested movie play rate.
 * @warning Depending on the underlying media, the requested rate may be
 * different from the real playback rate. Due to limitations of some protocols
 * this option may not be taken into account at all, if set.
 * \param rate movie play rate to set
 *
 * \return movie play rate
 */
@property float rate;

@property (readonly) VLCAudio * audio;

/* Video Information */
/**
 * Get the current video size
 * \return video size as CGSize
 */
- (CGSize)videoSize;
/**
 * Does the current media have a video output?
 * \note a false return value doesn't mean that the video doesn't have any video
 * \note tracks. Those might just be disabled.
 * \return current video output status
 */
- (BOOL)hasVideoOut;
/**
 * Frames per second
 * \return current media's frames per second value
 */
- (float)framesPerSecond;

#pragma mark -
#pragma mark time

/**
 * Sets the current position (or time) of the feed.
 * \param value New time to set the current position to.  If time is [VLCTime nullTime], 0 is assumed.
 */
- (void)setTime:(VLCTime *)value;

/**
 * Returns the current position (or time) of the feed.
 * \return VLCTIme object with current time.
 */
- (VLCTime *)time;

@property (readonly) VLCTime *remainingTime;

/**
 * Frames per second
 * \note this property is deprecated. use (float)fps instead.
 * \return current media's frames per second value
 */
@property (readonly) NSUInteger fps __attribute__((deprecated));

#pragma mark -
#pragma mark ES track handling

/**
 * Return the current video track index
 * Note that the handled values do not match the videoTracks array indexes
 * but refer to videoSubTitlesIndexes.
 * \return 0 if none is set.
 *
 * Pass -1 to disable.
 */
@property (readwrite) NSUInteger currentVideoTrackIndex;

/**
 * Returns the video track names, usually a language name or a description
 * It includes the "Disabled" fake track at index 0.
 */
- (NSArray *)videoTrackNames;

/**
 * Returns the video track IDs
 * those are needed to set the video index
 */
- (NSArray *)videoTrackIndexes;

/**
 * Return the video tracks
 *
 * It includes the disabled fake track at index 0.
 */
- (NSArray *)videoTracks __attribute__((deprecated));

/**
 * Return the current video subtitle index
 * Note that the handled values do not match the videoSubTitles array indexes
 * but refer to videoSubTitlesIndexes
 * \return 0 if none is set.
 *
 * Pass -1 to disable.
 */
@property (readwrite) NSUInteger currentVideoSubTitleIndex;

/**
 * Returns the video subtitle track names, usually a language name or a description
 * It includes the "Disabled" fake track at index 0.
 */
- (NSArray *)videoSubTitlesNames;

/**
 * Returns the video subtitle track IDs
 * those are needed to set the video subtitle index
 */
- (NSArray *)videoSubTitlesIndexes;

/**
 * Return the video subtitle tracks
 * \note this property is deprecated. use (NSArray *)videoSubtitleNames instead.
 * It includes the disabled fake track at index 0.
 */
- (NSArray *)videoSubTitles __attribute__((deprecated));

/**
 * Load and set a specific video subtitle, from a file.
 * \param path to a file
 * \return if the call succeed..
 */
- (BOOL)openVideoSubTitlesFromFile:(NSString *)path;

/**
 * Get the current subtitle delay. Positive values means subtitles are being
 * displayed later, negative values earlier.
 *
 * \return time (in microseconds) the display of subtitles is being delayed
 */
@property (readwrite) NSInteger currentVideoSubTitleDelay;

/**
 * Chapter selection and enumeration, it is bound
 * to a title option.
 */

/**
 * Return the current video subtitle index, or
 * \return NSNotFound if none is set.
 *
 * To disable subtitle pass NSNotFound.
 */
@property (readwrite) int currentChapterIndex;
- (void)previousChapter;
- (void)nextChapter;
- (NSArray *)chaptersForTitleIndex:(int)titleIndex;

/**
 * Title selection and enumeration
 * \return NSNotFound if none is set.
 */
@property (readwrite) NSUInteger currentTitleIndex;
- (NSArray *)titles;

/* Audio Options */

/**
 * Return the current audio track index
 * Note that the handled values do not match the audioTracks array indexes
 * but refer to audioTrackIndexes.
 * \return 0 if none is set.
 *
 * Pass -1 to disable.
 */
@property (readwrite) NSUInteger currentAudioTrackIndex;

/**
 * Returns the audio track names, usually a language name or a description
 * It includes the "Disabled" fake track at index 0.
 */
- (NSArray *)audioTrackNames;

/**
 * Returns the audio track IDs
 * those are needed to set the video index
 */
- (NSArray *)audioTrackIndexes;

/**
 * Return the audio tracks
 *
 * It includes the "Disable" fake track at index 0.
 */
- (NSArray *)audioTracks __attribute__((deprecated));

#pragma mark -
#pragma mark audio functionality

- (void)setAudioChannel:(int)value;
- (int)audioChannel;

/**
 * Get the current audio delay. Positive values means audio is delayed further,
 * negative values less.
 *
 * \return time (in microseconds) the audio playback is being delayed
 */
@property (readwrite) NSInteger currentAudioPlaybackDelay;

#pragma mark -
#pragma mark equalizer

/**
 * Get a list of available equalizer profiles
 * \Note Current versions do not allow the addition of further profiles
 *       so you need to handle this in your app.
 *
 * \return array of equalizer profiles
 */
@property (readonly) NSArray *equalizerProfiles;

/**
 * Re-set the equalizer to a profile retrieved from the list
 * \Note This doesn't enable the Equalizer automagically
 */
- (void)resetEqualizerFromProfile:(unsigned)profile;

/**
 * Toggle equalizer state
 * \param bool value to enable/disable the equalizer
 * \return current state */
@property (readwrite) BOOL equalizerEnabled;

/**
 * Set amplification level
 * \param The supplied amplification value will be clamped to the -20.0 to +20.0 range.
 * \note this will create and enabled an Equalizer instance if not present
 * \return current amplification level */
@property (readwrite) CGFloat preAmplification;

/**
 * Number of equalizer bands
 * \return the number of equalizer bands available in the current release */
@property (readonly) unsigned numberOfBands;

/**
 * frequency of equalizer band
 * \return frequency of the requested equalizer band */
- (CGFloat)frequencyOfBandAtIndex:(unsigned)index;

/**
 * set amplification for band
 * \param amplification value (clamped to the -20.0 to +20.0 range)
 * \param index of the respective band */
- (void)setAmplification:(CGFloat)amplification forBand:(unsigned)index;

/**
 * amplification of band
 * \param index of the band
 * \return current amplification value (clamped to the -20.0 to +20.0 range) */
- (CGFloat)amplificationOfBand:(unsigned)index;

#pragma mark -
#pragma mark media handling

/* Media Options */
- (void)setMedia:(VLCMedia *)value;
- (VLCMedia *)media;

#pragma mark -
#pragma mark playback operations
/**
 * Plays a media resource using the currently selected media controller (or
 * default controller.  If feed was paused then the feed resumes at the position
 * it was paused in.
 * \return A Boolean determining whether the stream was played or not.
 */
- (BOOL)play;

/**
 * Toggle's the pause state of the feed.
 */
- (void)pause;

/**
 * Stop the playing.
 */
- (void)stop;

/**
 * Advance one frame.
 */
- (void)gotoNextFrame;

/**
 * Fast forwards through the feed at the standard 1x rate.
 */
- (void)fastForward;

/**
 * Fast forwards through the feed at the rate specified.
 * \param rate Rate at which the feed should be fast forwarded.
 */
- (void)fastForwardAtRate:(float)rate;

/**
 * Rewinds through the feed at the standard 1x rate.
 */
- (void)rewind;

/**
 * Rewinds through the feed at the rate specified.
 * \param rate Rate at which the feed should be fast rewound.
 */
- (void)rewindAtRate:(float)rate;

/**
 * Jumps shortly backward in current stream if seeking is supported.
 * \param interval to skip, in sec.
 */
- (void)jumpBackward:(int)interval;

/**
 * Jumps shortly forward in current stream if seeking is supported.
 * \param interval to skip, in sec.
 */
- (void)jumpForward:(int)interval;

/**
 * Jumps shortly backward in current stream if seeking is supported.
 */
- (void)extraShortJumpBackward;

/**
 * Jumps shortly forward in current stream if seeking is supported.
 */
- (void)extraShortJumpForward;

/**
 * Jumps shortly backward in current stream if seeking is supported.
 */
- (void)shortJumpBackward;

/**
 * Jumps shortly forward in current stream if seeking is supported.
 */
- (void)shortJumpForward;

/**
 * Jumps shortly backward in current stream if seeking is supported.
 */
- (void)mediumJumpBackward;

/**
 * Jumps shortly forward in current stream if seeking is supported.
 */
- (void)mediumJumpForward;

/**
 * Jumps shortly backward in current stream if seeking is supported.
 */
- (void)longJumpBackward;

/**
 * Jumps shortly forward in current stream if seeking is supported.
 */
- (void)longJumpForward;

#pragma mark -
#pragma mark playback information
/**
 * Playback state flag identifying that the stream is currently playing.
 * \return TRUE if the feed is playing, FALSE if otherwise.
 */
- (BOOL)isPlaying;

/**
 * Playback state flag identifying wheather the stream will play.
 * \return TRUE if the feed is ready for playback, FALSE if otherwise.
 */
- (BOOL)willPlay;

/**
 * Playback's current state.
 * \see VLCMediaState
 */
- (VLCMediaPlayerState)state;

/**
 * Returns the receiver's position in the reading.
 * \return movie position as percentage between 0.0 and 1.0.
 */
- (float)position;
/**
 * Set movie position. This has no effect if playback is not enabled.
 * \param movie position as percentage between 0.0 and 1.0.
 */
- (void)setPosition:(float)newPosition;

- (BOOL)isSeekable;

- (BOOL)canPause;

@end
