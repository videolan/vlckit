/*****************************************************************************
 * VLCMediaPlayer.m: VLCKit.framework VLCMediaPlayer implementation
 *****************************************************************************
 * Copyright (C) 2007-2009 Pierre d'Herbemont
 * Copyright (C) 2007-2024 VLC authors and VideoLAN
 * Partial Copyright (C) 2009-2024 Felix Paul Kühne
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *          Faustion Osuna <enrique.osuna # gmail.com>
 *          Felix Paul Kühne <fkuehne # videolan.org>
 *          Soomin Lee <TheHungryBu # gmail.com>
 *          Maxime Chapelet <umxprime # videolabs.io>
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

#import <VLCLibrary.h>
#import <VLCLibVLCBridging.h>
#import <VLCMediaPlayer.h>
#import <VLCTime.h>
#import <VLCMediaPlayer+Internal.h>
#import <VLCAdjustFilter.h>
#import <VLCAudioEqualizer.h>
#import <VLCEventsHandler.h>
#import <VLCAudio.h>
#import <VLCMediaPlayerTitleDescription.h>
#if !TARGET_OS_IPHONE
# import <VLCVideoView.h>
#endif // !TARGET_OS_IPHONE
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#if !TARGET_OS_IPHONE
/* prevent system sleep */
# import <CoreServices/CoreServices.h>
# import <IOKit/pwr_mgt/IOPMLib.h>
#endif // !TARGET_OS_IPHONE

#include <vlc/vlc.h>
#include <errno.h>

/* Notification Messages */
NSNotificationName const VLCMediaPlayerTimeChangedNotification = @"VLCMediaPlayerTimeChangedNotification";
NSNotificationName const VLCMediaPlayerStateChangedNotification = @"VLCMediaPlayerStateChangedNotification";
NSNotificationName const VLCMediaPlayerTitleSelectionChangedNotification = @"VLCMediaPlayerTitleSelectionChangedNotification";
NSNotificationName const VLCMediaPlayerTitleListChangedNotification = @"VLCMediaPlayerTitleListChangedNotification";
NSNotificationName const VLCMediaPlayerChapterChangedNotification = @"VLCMediaPlayerChapterChangedNotification";
NSNotificationName const VLCMediaPlayerSnapshotTakenNotification = @"VLCMediaPlayerSnapshotTakenNotification";
NSNotificationName const VLCMediaPlayerProgramListChangedNotification = @"VLCMediaPlayerProgramListChangedNotification";
NSNotificationName const VLCMediaPlayerProgramSelectionChangedNotification = @"VLCMediaPlayerProgramSelectionChangedNotification";
NSNotificationName const VLCMediaPlayerCapabilitiesChangedNotification = @"VLCMediaPlayerCapabilitiesChangedNotification";

static_assert(VLCAudioStereoModeUnset == libvlc_AudioStereoMode_Unset
           && VLCAudioStereoModeStereo == libvlc_AudioStereoMode_Stereo
           && VLCAudioStereoModeRStereo == libvlc_AudioStereoMode_RStereo
           && VLCAudioStereoModeLeft == libvlc_AudioStereoMode_Left
           && VLCAudioStereoModeRight == libvlc_AudioStereoMode_Right
           && VLCAudioStereoModeDolbys == libvlc_AudioStereoMode_Dolbys
           && VLCAudioStereoModeMono == libvlc_AudioStereoMode_Mono
              , "Audio stereo mode doesn't match with libvlc");

static_assert(VLCAudioMixModeUnset == libvlc_AudioMixMode_Unset
           && VLCAudioMixModeStereo == libvlc_AudioMixMode_Stereo
           && VLCAudioMixModeBinaural == libvlc_AudioMixMode_Binaural
           && VLCAudioMixMode4_0 == libvlc_AudioMixMode_4_0
           && VLCAudioMixMode5_1 == libvlc_AudioMixMode_5_1
           && VLCAudioMixMode7_1 == libvlc_AudioMixMode_7_1
              , "Audio mix mode doesn't match with libvlc");

NSString * VLCMediaPlayerStateToString(VLCMediaPlayerState state)
{
    static NSString * stateToStrings[] = {
        [VLCMediaPlayerStateStopped]      = @"VLCMediaPlayerStateStopped",
        [VLCMediaPlayerStateStopping]     = @"VLCMediaPlayerStateStopping",
        [VLCMediaPlayerStateOpening]      = @"VLCMediaPlayerStateOpening",
        [VLCMediaPlayerStateError]        = @"VLCMediaPlayerStateError",
        [VLCMediaPlayerStatePlaying]      = @"VLCMediaPlayerStatePlaying",
        [VLCMediaPlayerStatePaused]       = @"VLCMediaPlayerStatePaused",
    };
    return stateToStrings[state];
}

#if !TARGET_OS_IPHONE
// Display sleep assertion for preventing screen sleep during playback
static IOPMAssertionID displaySleepAssertion = 0;
#endif

// TODO: Documentation
@interface VLCMediaPlayer (Private)

@property (NS_NONATOMIC_IOSONLY, getter=isSeeking, readwrite) BOOL seeking;

- (instancetype)initWithDrawable:(id)aDrawable options:(NSArray *)options;

- (dispatch_queue_t)libVLCBackgroundQueue;
- (void)mediaPlayerLastTimePointUpdated:(const libvlc_media_player_time_point_t)newTimePoint;
- (void)mediaPlayerHandleTimeDiscontinuity:(int64_t)systemDate;
- (void)mediaPlayerStateChanged:(const VLCMediaPlayerState)newState;
- (void)mediaPlayerMediaChanged:(VLCMedia *)media;
- (void)mediaPlayerTitleSelectionChanged:(const int)newTitle;
- (void)mediaPlayerChapterChanged:(NSNumber *)newChapter;
- (void)mediaPlayerTitleListChanged:(NSString *)newTitleList;
- (void)mediaPlayerCapabilitiesChanged;

- (void)mediaPlayerSnapshot:(NSString *)fileName;
@end

@interface VLCMediaPlayer ()
{
    VLCLibrary *_privateLibrary;                ///< Internal
    libvlc_media_player_t * _playerInstance;    ///< Internal
    VLCMedia * _media;                          ///< Current media being played
    libvlc_media_player_time_point_t _lastTimePoint; ///< Cached time point of the media being played
    double _lastInterpolatedPosition;           ///< Cached position of the media being played
    int64_t _lastInterpolatedTime;              ///< Cached time of the media being played
    int64_t _systemDateOfDiscontinuity;
    BOOL _timeDiscontinuityState;
    BOOL _isSeeking;
    dispatch_block_t _onSeekCompletion;
    VLCMediaPlayerState _cachedState;           ///< Cached state of the media being played
    id _drawable;                               ///< The drawable associated to this media player
    NSMutableArray *_snapshots;                 ///< Array with snapshot file names
    VLCAudio *_audio;                           ///< The audio controller
    libvlc_video_viewpoint_t *_viewpoint;       ///< Current viewpoint of the media
    dispatch_queue_t _libVLCBackgroundQueue;    ///< Background dispatch queue to call libvlc
    int64_t _minimalWatchTimePeriod;            ///< Minimal period for the watch timer
    VLCEventsHandler*       _eventsHandler;     ///< Handles libvlc event callbacks
}

/// Timer used to update time watch point interpolation on regular intervals
@property (nonatomic) NSTimer *timeChangeUpdateTimer;
@property (nonatomic) dispatch_queue_t timeChangeLockQueue;
@property (NS_NONATOMIC_IOSONLY, getter=isSeeking, readwrite) BOOL seeking;
@property (NS_NONATOMIC_IOSONLY) dispatch_block_t onSeekCompletion;

@end

static void HandleWatchTimeUpdate(void *opaque,
                                  const libvlc_media_player_time_point_t *value)
{
    if (value == NULL || value->ts_us == -1) {
        return;
    }
    libvlc_media_player_time_point_t const newValue = *value;
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            [mediaPlayer mediaPlayerLastTimePointUpdated:newValue];
        }];
    }
}

static void HandleWatchTimeDiscontinuity(void *opaque, int64_t system_date_us)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            [mediaPlayer mediaPlayerHandleTimeDiscontinuity:system_date_us];
        }];
    }
}

static void HandleWatchTimeOnSeek(void *opaque,
                                  const libvlc_media_player_time_point_t *value)
{
    BOOL isSeeking = YES;
    libvlc_media_player_time_point_t newTimePoint = {};
    if (value == NULL) {
        isSeeking = NO;
    } else {
        newTimePoint = *value;
    }
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            if (isSeeking)
                [mediaPlayer mediaPlayerLastTimePointUpdated:newTimePoint];
            else if (mediaPlayer.isSeeking && mediaPlayer.onSeekCompletion) {
                dispatch_block_t onSeekCompletion = mediaPlayer.onSeekCompletion;
                dispatch_async(dispatch_get_main_queue(), onSeekCompletion);
                mediaPlayer.onSeekCompletion = nil;
            }
            mediaPlayer.seeking = isSeeking;
        }];
    }
}

static void HandleMediaInstanceStateChanged(void *opaque, libvlc_state_t state)
{
    VLCMediaPlayerState newState;

    switch (state) {
        case libvlc_Playing:
            newState = VLCMediaPlayerStatePlaying;
            break;
        case libvlc_Paused:
            newState = VLCMediaPlayerStatePaused;
            break;
        case libvlc_Stopping:
            newState = VLCMediaPlayerStateStopping;
            break;
        case libvlc_Stopped:
            newState = VLCMediaPlayerStateStopped;
            break;
        case libvlc_Error:
            newState = VLCMediaPlayerStateError;
            break;
        case libvlc_Opening:
            newState = VLCMediaPlayerStateOpening;
            break;

        default:
            VKLog(@"%s: Unknown event", __FUNCTION__);
            return;
    }

    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            [mediaPlayer mediaPlayerStateChanged: newState];
            NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerStateChangedNotification object: mediaPlayer];
            [[NSNotificationCenter defaultCenter] postNotification: notification];
            if([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerStateChanged:)])
                [mediaPlayer.delegate mediaPlayerStateChanged:newState];
        }];
    }
}

static void HandleMediaPlayerBuffering(void *opaque, float buffering)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerBufferingChanged:)])
                [mediaPlayer.delegate mediaPlayerBufferingChanged:buffering];
        }];
    }
}

static void HandleMediaPlayerAudioVolumeChanged(void *opaque, float volume)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerVolumeChangedNotification object: mediaPlayer];
            [[NSNotificationCenter defaultCenter] postNotification: notification];
        }];
    }
}

static VLCMediaTrackType GetMediaTrackType(libvlc_track_type_t trackType)
{
    switch (trackType)
    {
        case libvlc_track_audio:
            return VLCMediaTrackTypeAudio;
        case libvlc_track_text:
            return VLCMediaTrackTypeText;
        case libvlc_track_video:
            return VLCMediaTrackTypeVideo;
        default:
            return VLCMediaTrackTypeUnknown;
    }
}

static void HandleMediaPlayerTrackChanged(void *opaque, libvlc_list_action_t action,
                                          libvlc_track_type_t type, const char *track_id)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        NSString *trackName = track_id ? [NSString stringWithUTF8String:track_id] : nil;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaTrackType trackType = GetMediaTrackType(type);
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            switch (action)
            {
                case libvlc_list_action_added:
                {
                    SEL selector = @selector(mediaPlayerTrackAdded:withType:);
                    if([mediaPlayer.delegate respondsToSelector:selector])
                        [mediaPlayer.delegate mediaPlayerTrackAdded:trackName
                                                           withType:trackType];
                }
                    break;
                case libvlc_list_action_updated:
                {
                    SEL selector = @selector(mediaPlayerTrackUpdated:withType:);
                    if([mediaPlayer.delegate respondsToSelector:selector])
                        [mediaPlayer.delegate mediaPlayerTrackUpdated:trackName
                                                             withType:trackType];
                }
                    break;
                case libvlc_list_action_removed:
                {
                    SEL selector = @selector(mediaPlayerTrackRemoved:withType:);
                    if([mediaPlayer.delegate respondsToSelector:selector])
                        [mediaPlayer.delegate mediaPlayerTrackRemoved:trackName
                                                             withType:trackType];
                }
                    break;
                default:
                    return; // TODO unreachable
            }
        }];
    };
}

static void HandleMediaPlayerTrackSelectionChanged(void *opaque, libvlc_track_type_t type,
                                                   const char *unselected,
                                                   const char *selected)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        NSString *selectedId = selected ? [NSString stringWithUTF8String:selected] : nil;
        NSString *unselectedId = unselected ? [NSString stringWithUTF8String:unselected] : nil;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaTrackType trackType = GetMediaTrackType(type);

            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            SEL selector = @selector(mediaPlayerTrackSelected:selectedId:unselectedId:);
            if([mediaPlayer.delegate respondsToSelector:selector])
                [mediaPlayer.delegate mediaPlayerTrackSelected:trackType
                                                    selectedId:selectedId
                                                  unselectedId:unselectedId];
        }];
    }
}

static void HandleMediaPlayerMediaChanged(void *opaque, libvlc_media_t *libvlc_media)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMedia *newMedia = nil;
            if (libvlc_media != NULL) {
                newMedia = (__bridge VLCMedia *)libvlc_media_get_user_data(libvlc_media);
                if (newMedia == nil) {
                    newMedia = [VLCMedia mediaWithLibVLCMediaDescriptor:libvlc_media];
                }
            }
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            [mediaPlayer mediaPlayerMediaChanged: newMedia];
        }];
    }
}

static void HandleMediaPlayerMediaMetaChanged(void *opaque, libvlc_media_t *libvlc_media)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            if (libvlc_media == NULL)
                return;
            VLCMedia *media = (__bridge VLCMedia *)libvlc_media_get_user_data(libvlc_media);
            if (media == nil)
                media = [VLCMedia mediaWithLibVLCMediaDescriptor:libvlc_media];
            [media metaChanged];
        }];
    }
}

static void HandleMediaPlayerMediaSubItemsChanged(void *opaque, libvlc_media_t *libvlc_media)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            if (libvlc_media == NULL)
                return;
            VLCMedia *media = (__bridge VLCMedia *)libvlc_media_get_user_data(libvlc_media);
            if (media == nil)
                media = [VLCMedia mediaWithLibVLCMediaDescriptor:libvlc_media];
            [media subitemsChanged];
        }];
    }
}

static void HandleMediaPlayerMediaAttachmentsAdded(void *opaque, libvlc_media_t *libvlc_media,
                                                   libvlc_picture_list_t *list)
{
    @autoreleasepool {
        if (libvlc_media == NULL || list == NULL)
            return;

        /* The picture list is only valid during this callback, so copy out the
         * first decodable attachment before dispatching to the delegate. */
        NSData *artworkData = nil;
        size_t count = libvlc_picture_list_count(list);
        for (size_t i = 0; i < count; i++) {
            libvlc_picture_t *picture = libvlc_picture_list_at(list, i);
            if (picture == NULL)
                continue;
            size_t size = 0;
            const uint8_t *buffer = libvlc_picture_get_buffer(picture, &size);
            if (buffer != NULL && size > 0) {
                artworkData = [NSData dataWithBytes:buffer length:size];
                break;
            }
        }
        if (artworkData == nil)
            return;

        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMedia *media = (__bridge VLCMedia *)libvlc_media_get_user_data(libvlc_media);
            if (media == nil)
                media = [VLCMedia mediaWithLibVLCMediaDescriptor:libvlc_media];
            [media artworkAttachmentReceived:artworkData];
        }];
    }
}

static void HandleMediaTitleSelectionChanged(void *opaque,
                                             const libvlc_title_description_t *title,
                                             unsigned idx)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            [mediaPlayer mediaPlayerTitleSelectionChanged: idx];
            NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerTitleSelectionChangedNotification object: mediaPlayer];
            [[NSNotificationCenter defaultCenter] postNotification: notification];
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerTitleSelectionChanged:)])
                [mediaPlayer.delegate mediaPlayerTitleSelectionChanged: notification];
        }];
    }
}

static void HandleMediaTitleListChanged(void * opaque)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            [mediaPlayer mediaPlayerTitleListChanged: VLCMediaPlayerTitleListChangedNotification];
            NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerTitleListChangedNotification object: mediaPlayer];
            [[NSNotificationCenter defaultCenter] postNotification: notification];
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerTitleListChanged:)])
                [mediaPlayer.delegate mediaPlayerTitleListChanged: notification];
        }];
    }
}

static void HandleMediaPlayerCapabilitiesChanged(void *opaque, libvlc_capability_t old_caps,
                                                 libvlc_capability_t new_caps)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            [mediaPlayer mediaPlayerCapabilitiesChanged];
            NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerCapabilitiesChangedNotification object: mediaPlayer];
            [[NSNotificationCenter defaultCenter] postNotification: notification];
        }];
    }
}

static void HandleMediaProgramListChanged(void *opaque, libvlc_list_action_t action,
                                          int group_id)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerProgramListChangedNotification object: mediaPlayer];
            [[NSNotificationCenter defaultCenter] postNotification: notification];
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerProgramListChanged:)])
                [mediaPlayer.delegate mediaPlayerProgramListChanged: notification];
        }];
    }
}

static void HandleMediaProgramSelectionChanged(void *opaque, int unselected_group_id,
                                               int selected_group_id)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerProgramSelectionChangedNotification object: mediaPlayer];
            [[NSNotificationCenter defaultCenter] postNotification: notification];
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerProgramSelectionChanged:)])
                [mediaPlayer.delegate mediaPlayerProgramSelectionChanged: notification];
        }];
    }
}

static void HandleMediaChapterChanged(void *opaque,
                                      const libvlc_title_description_t *title,
                                      unsigned title_idx,
                                      const libvlc_chapter_description_t *chapter,
                                      unsigned chapter_idx)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerChapterChangedNotification object: mediaPlayer];
            [[NSNotificationCenter defaultCenter] postNotification: notification];
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerChapterChanged:)])
                [mediaPlayer.delegate mediaPlayerChapterChanged: notification];
        }];
    }
}

static void HandleMediaPlayerLengthChanged(void *opaque, libvlc_time_t length)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerLengthChanged:)])
                [mediaPlayer.delegate mediaPlayerLengthChanged:length / 1000];
        }];
    }
}

static void HandleMediaPlayerSnapshot(void *opaque, const char *psz_filepath)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        NSString *fileName = psz_filepath ? @(psz_filepath) : nil;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            if (fileName) {
                VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
                [mediaPlayer mediaPlayerSnapshot: fileName];
                NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerSnapshotTakenNotification object: mediaPlayer];
                [[NSNotificationCenter defaultCenter] postNotification: notification];
                if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayerSnapshot:)])
                    [mediaPlayer.delegate mediaPlayerSnapshot: notification];
            }
        }];
    }
}

static void HandleMediaPlayerRecord(void *opaque, bool recording,
                                    const char *psz_filepath)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        NSString *filePath = psz_filepath ? @(psz_filepath) : nil;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            if (recording) {
                if ([mediaPlayer.delegate respondsToSelector: @selector(mediaPlayerStartedRecording:)])
                    [mediaPlayer.delegate mediaPlayerStartedRecording: mediaPlayer];
            } else {
                if ([mediaPlayer.delegate respondsToSelector: @selector(mediaPlayer:recordingStoppedAtURL:)]) {
                    NSURL *url = [filePath hasPrefix: @"/"] ? [NSURL fileURLWithPath: filePath isDirectory: NO] : nil;
                    [mediaPlayer.delegate mediaPlayer: mediaPlayer recordingStoppedAtURL: url];
                }
            }
        }];
    }
}

static VLCMediaPlayerFrameStepResult GetFrameStepResult(int status)
{
    switch (-status) {
        case 0:       return VLCMediaPlayerFrameStepResultSuccess;
        case EAGAIN:  return VLCMediaPlayerFrameStepResultPending;
        case EBUSY:   return VLCMediaPlayerFrameStepResultVideoError;
        case ENOTSUP: return VLCMediaPlayerFrameStepResultCannotPause;
        case ERANGE:  return VLCMediaPlayerFrameStepResultCannotSeekBack;
        case EINVAL:
        default:      return VLCMediaPlayerFrameStepResultInvalidState;
    }
}

static void HandleMediaPlayerNextFrameStatus(void *opaque, int status)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        VLCMediaPlayerFrameStepResult result = GetFrameStepResult(status);
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayer:nextFrameSteppedWithResult:)])
                [mediaPlayer.delegate mediaPlayer:mediaPlayer nextFrameSteppedWithResult:result];
        }];
    }
}

static void HandleMediaPlayerPreviousFrameStatus(void *opaque, int status)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        VLCMediaPlayerFrameStepResult result = GetFrameStepResult(status);
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaPlayer *mediaPlayer = (VLCMediaPlayer *)object;
            if ([mediaPlayer.delegate respondsToSelector:@selector(mediaPlayer:previousFrameSteppedWithResult:)])
                [mediaPlayer.delegate mediaPlayer:mediaPlayer previousFrameSteppedWithResult:result];
        }];
    }
}

@implementation VLCMediaPlayer
@synthesize libraryInstance = _privateLibrary;

/* Bindings */
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    static NSDictionary * dict = nil;
    NSSet * superKeyPaths;
    if (!dict) {
        dict = @{@"playing": [NSSet setWithObject:@"state"],
                @"seekable": [NSSet setWithObjects:@"state", @"media", nil],
                @"canPause": [NSSet setWithObjects:@"state", @"media", nil],
                @"description": [NSSet setWithObjects:@"state", @"media", nil]};
    }
    if ((superKeyPaths = [super keyPathsForValuesAffectingValueForKey: key])) {
        NSMutableSet * ret = [NSMutableSet setWithSet:dict[key]];
        [ret unionSet:superKeyPaths];
        return ret;
    }
    return dict[key];
}

/* Constructor */
- (instancetype)init
{
    return [self initWithDrawable:nil options:nil];
}

- (instancetype)initCommon
{
    if (self = [super init]) {
        _adjustFilter = [VLCAdjustFilter createWithVLCMediaPlayer:self];
        _timeChangeLockQueue = dispatch_queue_create("org.videolan.vlcmediaplayer.timechangelock", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _lastTimePoint.ts_us = -1;
        _timeChangeUpdateInterval = 1.0;
        _eventsHandler = [VLCEventsHandler handlerWithObject:self configuration:[VLCLibrary sharedEventsConfiguration]];
    }
    return self;
}

- (instancetype)initWithLibrary:(VLCLibrary *)library
{
    if (self = [self initCommon]) {
        _cachedState = VLCMediaPlayerStateStopped;
        _libVLCBackgroundQueue = [self libVLCBackgroundQueue];
        _minimalWatchTimePeriod = 500000;
        _privateLibrary = library;
        static const struct libvlc_media_player_cbs player_cbs = {
            .version = 0,
            .on_state_changed = HandleMediaInstanceStateChanged,
            .on_buffering_changed = HandleMediaPlayerBuffering,
            .on_capabilities_changed = HandleMediaPlayerCapabilitiesChanged,
            .on_length_changed = HandleMediaPlayerLengthChanged,
            .on_track_list_changed = HandleMediaPlayerTrackChanged,
            .on_track_selection_changed = HandleMediaPlayerTrackSelectionChanged,
            .on_media_changed = HandleMediaPlayerMediaChanged,
            .on_media_meta_changed = HandleMediaPlayerMediaMetaChanged,
            .on_media_subitems_changed = HandleMediaPlayerMediaSubItemsChanged,
            .on_media_attachments_added = HandleMediaPlayerMediaAttachmentsAdded,
            .on_title_selection_changed = HandleMediaTitleSelectionChanged,
            .on_titles_changed = HandleMediaTitleListChanged,
            .on_chapter_selection_changed = HandleMediaChapterChanged,
            .on_program_list_changed = HandleMediaProgramListChanged,
            .on_program_selection_changed = HandleMediaProgramSelectionChanged,
            .on_screenshot_taken = HandleMediaPlayerSnapshot,
            .on_recording_changed = HandleMediaPlayerRecord,
            .on_audio_volume_changed = HandleMediaPlayerAudioVolumeChanged,
            .on_next_frame_status = HandleMediaPlayerNextFrameStatus,
            .on_prev_frame_status = HandleMediaPlayerPreviousFrameStatus,
        };
        _playerInstance = libvlc_media_player_new([_privateLibrary instance],
                                                  &player_cbs, (__bridge void *)_eventsHandler);
        if (_playerInstance == NULL) {
            NSAssert(0, @"%s: player initialization failed", __PRETTY_FUNCTION__);
            return nil;
        }

        static const struct libvlc_media_player_watch_time_cbs watch_time_cbs = {
            .version = 0,
            .on_update = HandleWatchTimeUpdate,
            .on_paused = HandleWatchTimeDiscontinuity,
            .on_seek = HandleWatchTimeOnSeek,
        };

        libvlc_media_player_watch_time(_playerInstance, _minimalWatchTimePeriod,
                                       &watch_time_cbs, (__bridge void *)_eventsHandler);
    }
    return self;

}

- (instancetype)initWithLibVLCInstance:(void *)playerInstance andLibrary:(VLCLibrary *)library
{
    if (self = [self initCommon]) {
        _cachedState = VLCMediaPlayerStateStopped;
        _libVLCBackgroundQueue = [self libVLCBackgroundQueue];
        _minimalWatchTimePeriod = 500000;

        _privateLibrary = library;

        _playerInstance = playerInstance;

        static const struct libvlc_media_player_watch_time_cbs watch_time_cbs = {
            .version = 0,
            .on_update = HandleWatchTimeUpdate,
            .on_paused = HandleWatchTimeDiscontinuity,
            .on_seek = HandleWatchTimeOnSeek,
        };
        libvlc_media_player_watch_time(_playerInstance, _minimalWatchTimePeriod,
                                       &watch_time_cbs, (__bridge void *)_eventsHandler);
    }
    return self;
}

#if !TARGET_OS_IPHONE
- (instancetype)initWithVideoView:(VLCVideoView *)aVideoView
{
    return [self initWithDrawable: aVideoView options:nil];
}

- (instancetype)initWithVideoLayer:(VLCVideoLayer *)aVideoLayer
{
    return [self initWithDrawable: aVideoLayer options:nil];
}

- (instancetype)initWithVideoView:(VLCVideoView *)aVideoView options:(NSArray *)options
{
    return [self initWithDrawable: aVideoView options:options];
}

- (instancetype)initWithVideoLayer:(VLCVideoLayer *)aVideoLayer options:(NSArray *)options
{
    return [self initWithDrawable: aVideoLayer options:options];
}
#endif

- (instancetype)initWithOptions:(NSArray *)options
{
    return [self initWithDrawable:nil options:options];
}

- (void)dealloc
{
    [self stopTimeChangeUpdateTimer];
#if !TARGET_OS_IPHONE
    [self allowDisplaySleep];
#endif
    libvlc_media_player_unwatch_time(_playerInstance);

    // Always get rid of the delegate first so we can stop sending messages to it
    // TODO: Should we tell the delegate that we're shutting down?
    _delegate = nil;

    // Clear our drawable as we are going to release it, we don't
    // want the core to use it from this point.
    libvlc_media_player_set_nsobject(_playerInstance, nil);
    _drawable = nil;

    libvlc_media_player_set_equalizer(_playerInstance, NULL);

    if (_viewpoint)
        libvlc_free(_viewpoint);

    libvlc_media_player_release(_playerInstance);
}

#if !TARGET_OS_IPHONE
- (void)setVideoView:(VLCVideoView *)aVideoView
{
    [self setDrawable: aVideoView];
}

- (void)setVideoLayer:(VLCVideoLayer *)aVideoLayer
{
    [self setDrawable: aVideoLayer];
}
#endif

- (void)setDrawable:(id)aDrawable
{
    // Make sure that this instance has been associated with the drawing canvas.
    _drawable = aDrawable;

    /* Note that ee need the caller to wait until the setter succeeded.
     * Otherwise, s/he might want to deploy the drawable while it isn’t ready yet. */
    dispatch_sync(_libVLCBackgroundQueue, ^{
        libvlc_media_player_set_nsobject(_playerInstance, (__bridge void *)(aDrawable));
    });
}

- (id)drawable
{
    return (__bridge id)(libvlc_media_player_get_nsobject(_playerInstance));
}

- (VLCAudio *)audio
{
    if (!_audio)
        _audio = [[VLCAudio alloc] initWithMediaPlayer:self];
    return _audio;
}



#pragma mark -
#pragma mark Subtitles

- (int)addPlaybackSlave:(NSURL *)slaveURL type:(VLCMediaPlaybackSlaveType)slaveType enforce:(BOOL)enforceSelection
{
    if (!slaveURL)
        return -1;

    return libvlc_media_player_add_slave(_playerInstance,
                                         (libvlc_media_slave_type_t)slaveType,
                                         [[slaveURL absoluteString] UTF8String],
                                         enforceSelection);
}

- (void)setCurrentVideoSubTitleDelay:(NSInteger)index
{
    libvlc_video_set_spu_delay(_playerInstance, index);
}

- (NSInteger)currentVideoSubTitleDelay
{
    return libvlc_video_get_spu_delay(_playerInstance);
}

- (void)setCurrentSubTitleFontScale:(float)scale
{
    libvlc_video_set_spu_text_scale(_playerInstance, scale);
}

- (float)currentSubTitleFontScale
{
    return libvlc_video_get_spu_text_scale(_playerInstance);
}

#if TARGET_OS_IPHONE
#warning text renderer API needs to be reimplemented in libvlc (#294)
- (void)setTextRendererFontSize:(NSNumber *)fontSize
{
//    libvlc_video_set_textrenderer_int(_playerInstance, libvlc_textrender_fontsize, [fontSize intValue]);
}

- (void)setTextRendererFont:(NSString *)fontname
{
//    libvlc_video_set_textrenderer_string(_playerInstance, libvlc_textrender_font, [fontname UTF8String]);
}

- (void)setTextRendererFontColor:(NSNumber *)fontColor
{
//    libvlc_video_set_textrenderer_int(_playerInstance, libvlc_textrender_fontcolor, [fontColor intValue]);
}

- (void)setTextRendererFontForceBold:(NSNumber *)fontForceBold
{
//    libvlc_video_set_textrenderer_bool(_playerInstance, libvlc_textrender_fontforcebold, [fontForceBold boolValue]);
}
#endif

#pragma mark -
#pragma mark Video Crop geometry

- (void)setCropRatioWithNumerator:(unsigned int)numerator denominator:(unsigned int)denominator
{
    libvlc_video_set_crop_ratio(_playerInstance, numerator, denominator);
}

- (void)setVideoAspectRatio:(nullable NSString *)videoAspectRatio
{
    libvlc_video_set_aspect_ratio(_playerInstance, videoAspectRatio.UTF8String);
}

- (nullable NSString *)videoAspectRatio
{
    char * result = libvlc_video_get_aspect_ratio(_playerInstance);
    if (!result)
        return nil;
    
    NSString *aspectRatio = @(result);
    libvlc_free(result);
    
    return aspectRatio;
}

- (void)setScaleFactor:(float)value
{
    libvlc_video_set_scale(_playerInstance, value);
}

- (float)scaleFactor
{
    return libvlc_video_get_scale(_playerInstance);
}

- (void)saveVideoSnapshotAt:(NSString *)path withWidth:(int)width andHeight:(int)height
{
    int failure = libvlc_video_take_snapshot(_playerInstance, 0, [path UTF8String], width, height);
    if (failure)
        [[NSException exceptionWithName:@"Can't take a video snapshot" reason:@"No video output" userInfo:nil] raise];
}

- (void)setDeinterlaceFilter:(nullable NSString *)name
{
    if (!name || name.length < 1)
        libvlc_video_set_deinterlace(_playerInstance, VLCDeinterlaceOff, NULL);
    else
        libvlc_video_set_deinterlace(_playerInstance, VLCDeinterlaceOn, [name UTF8String]);
}

- (void)setDeinterlace:(VLCDeinterlace)deinterlace withFilter:(NSString *)name
{
    libvlc_video_set_deinterlace(_playerInstance, (int)deinterlace, [name UTF8String]);
}

#pragma mark - Adjust Video Filter

- (BOOL)isAdjustFilterEnabled
{
    return _adjustFilter.isEnabled;
}
- (void)setAdjustFilterEnabled:(BOOL)b_value
{
    _adjustFilter.enabled = b_value;
}

- (float)contrast
{
    return [_adjustFilter.contrast.value floatValue];
}
- (void)setContrast:(float)f_value
{
    _adjustFilter.contrast.value = @(f_value);
}

- (float)brightness
{
    return [_adjustFilter.brightness.value floatValue];
}
- (void)setBrightness:(float)f_value
{
    _adjustFilter.brightness.value = @(f_value);
}

- (float)hue
{
    return [_adjustFilter.hue.value floatValue];
}
- (void)setHue:(float)f_value
{
    _adjustFilter.hue.value = @(f_value);
}

- (float)saturation
{
    return [_adjustFilter.saturation.value floatValue];
}
- (void)setSaturation:(float)f_value
{
    _adjustFilter.saturation.value = @(f_value);
}

- (float)gamma
{
    return [_adjustFilter.gamma.value floatValue];
}
- (void)setGamma:(float)f_value
{
    _adjustFilter.gamma.value = @(f_value);
}

#pragma mark -

- (void)setRate:(float)value
{
    libvlc_media_player_set_rate(_playerInstance, value);
}

- (float)rate
{
    return libvlc_media_player_get_rate(_playerInstance);
}

- (CGSize)videoSize
{
    unsigned height = 0, width = 0;
    int failure = libvlc_video_get_size(_playerInstance, 0, &width, &height);
    if (failure)
        return CGSizeZero;
    return CGSizeMake(width, height);
}

- (BOOL)hasVideoOut
{
    return libvlc_media_player_has_vout(_playerInstance);
}

- (void)setTime:(VLCTime *)value
{
    // VLCTime is in milliseconds; libvlc_media_player_set_time expects microseconds
    const libvlc_time_t time_us = value ? [[value value] longLongValue] * 1000 : 0;
    libvlc_media_player_set_time(_playerInstance, time_us, NO);
    [self timeChangeUpdate];
}

- (VLCTime *)time
{
    __block libvlc_media_player_time_point_t lastTimePoint;
    __block int64_t lastInterpolatedTime;
    dispatch_sync(_timeChangeLockQueue, ^{
        lastTimePoint = _lastTimePoint;
        lastInterpolatedTime = _lastInterpolatedTime;
    });

    if (lastTimePoint.ts_us == -1) {
        return [VLCTime nullTime];
    }

    return [VLCTime timeWithNumber:@(lastInterpolatedTime / 1000)];
}

- (VLCTime *)remainingTime
{
    __block libvlc_media_player_time_point_t lastTimePoint;
    __block int64_t lastInterpolatedTime;
    __block double lastInterpolatedPosition;
    dispatch_sync(_timeChangeLockQueue, ^{
        lastTimePoint = _lastTimePoint;
        lastInterpolatedTime = _lastInterpolatedTime;
        lastInterpolatedPosition = _lastInterpolatedPosition;
    });

    if (lastTimePoint.position == 0. || lastTimePoint.ts_us == -1) {
        return [VLCTime nullTime];
    }

    double remaining = ((lastInterpolatedTime / lastInterpolatedPosition) - lastInterpolatedTime) / 1000;
    return [VLCTime timeWithNumber:@(-remaining)];
}

- (void)setMinimalTimePeriod:(int64_t)minimalTimePeriod
{
    _minimalWatchTimePeriod = minimalTimePeriod;
    libvlc_media_player_unwatch_time(_playerInstance);

    static const struct libvlc_media_player_watch_time_cbs watch_time_cbs = {
        .version = 0,
        .on_update = HandleWatchTimeUpdate,
        .on_paused = HandleWatchTimeDiscontinuity,
        .on_seek = HandleWatchTimeOnSeek,
    };

    libvlc_media_player_watch_time(_playerInstance, _minimalWatchTimePeriod,
                                   &watch_time_cbs, (__bridge void *)_eventsHandler);
}

- (int64_t)minimalTimePeriod
{
    return _minimalWatchTimePeriod;
}

#pragma mark -
#pragma mark Chapters
- (void)setCurrentChapterIndex:(int)value;
{
    libvlc_media_player_set_chapter(_playerInstance, value);
}

- (int)currentChapterIndex
{
    int count = libvlc_media_player_get_chapter_count(_playerInstance);
    if (count <= 0)
        return -1;
    int result = libvlc_media_player_get_chapter(_playerInstance);
    return result;
}

- (void)setCurrentChapterDescription:(nullable VLCMediaPlayerChapterDescription *)currentChapterDescription
{
    [currentChapterDescription setCurrent];
}

- (nullable VLCMediaPlayerChapterDescription *)currentChapterDescription
{
    VLCMediaPlayerTitleDescription *currentTitleDescription = [self currentTitleDescription];
    if (!currentTitleDescription)
        return nil;
    
    for (VLCMediaPlayerChapterDescription *chapterDescription in currentTitleDescription.chapterDescriptions)
        if (chapterDescription.isCurrent)
            return chapterDescription;
    
    return nil;
}

- (void)nextChapter
{
    libvlc_media_player_next_chapter(_playerInstance);
}

- (void)previousChapter
{
    libvlc_media_player_previous_chapter(_playerInstance);
}

#pragma mark -
#pragma mark Titles

- (void)setCurrentTitleIndex:(int)value
{
    libvlc_media_player_set_title(_playerInstance, value);
}

- (int)currentTitleIndex
{
    NSInteger count = libvlc_media_player_get_title_count(_playerInstance);
    if (count <= 0)
        return -1;

    return libvlc_media_player_get_title(_playerInstance);
}

- (int)numberOfTitles
{
    return libvlc_media_player_get_title_count(_playerInstance);
}

- (void)setCurrentTitleDescription:(nullable VLCMediaPlayerTitleDescription *)currentTitleDescription
{
    [currentTitleDescription setCurrent];
}

- (nullable VLCMediaPlayerTitleDescription *)currentTitleDescription
{
    NSArray<VLCMediaPlayerTitleDescription *> *titles = [self titleDescriptions];
    for (VLCMediaPlayerTitleDescription *titleDescription in titles)
        if (titleDescription.isCurrent)
            return titleDescription;
        
    return nil;
}

- (NSArray<VLCMediaPlayerTitleDescription *> *)titleDescriptions
{
    libvlc_title_description_t **titles = NULL;
    const int count = libvlc_media_player_get_full_title_descriptions(_playerInstance, &titles);
    
    // -1 on error
    if (count == -1)
        return @[];
    else if (count == 0) {
        libvlc_title_descriptions_release(titles, count);
        return @[];
    }
    
    NSMutableArray<VLCMediaPlayerTitleDescription *> *array = [NSMutableArray arrayWithCapacity: (NSUInteger)count];
    for (int i = 0; i < count; i++) {
        VLCMediaPlayerTitleDescription *titleDescription = [[VLCMediaPlayerTitleDescription alloc] initWithMediaPlayer: self titleDescription: titles[i] titleIndex: i];
        [array addObject: titleDescription];
    }
    
    libvlc_title_descriptions_release(titles, count);
    
    return array;
}

- (int)indexOfLongestTitle
{
    NSArray<VLCMediaPlayerTitleDescription *> *titles = [self titleDescriptions];
    
    int currentlyFoundTitle = 0;
    int64_t currentlySelectedDuration = 0;
    int64_t randomTitleDuration = 0;
    
    for (VLCMediaPlayerTitleDescription *titleDescription in titles) {
        randomTitleDuration = titleDescription.durationTime.value.longLongValue;
        if (randomTitleDuration > currentlySelectedDuration) {
            currentlySelectedDuration = randomTitleDuration;
            currentlyFoundTitle = titleDescription.titleIndex;
        }
    }
    
    return currentlyFoundTitle;
}

- (nullable NSArray<VLCProgramDescription *> *)programs
{
    libvlc_player_programlist_t *list = libvlc_media_player_get_programlist(_playerInstance);
    if (list == NULL)
        return nil;

    const size_t count = libvlc_player_programlist_count(list);
    NSMutableArray<VLCProgramDescription *> *array = [NSMutableArray arrayWithCapacity: count];
    for (size_t i = 0; i < count; i++) {
        libvlc_player_program_t *program = libvlc_player_programlist_at(list, i);
        [array addObject: [[VLCProgramDescription alloc] initWithMediaPlayer: self program: program]];
    }
    libvlc_player_programlist_delete(list);

    return array;
}

- (nullable VLCProgramDescription *)selectedProgram
{
    libvlc_player_program_t *program = libvlc_media_player_get_selected_program(_playerInstance);
    if (program == NULL)
        return nil;

    VLCProgramDescription *description = [[VLCProgramDescription alloc] initWithMediaPlayer: self program: program];
    libvlc_player_program_delete(program);

    return description;
}

- (void)selectProgramWithIdentifier:(int)groupID
{
    libvlc_media_player_select_program_id(_playerInstance, groupID);
}

- (BOOL)isProgramScrambled
{
    return libvlc_media_player_program_scrambled(_playerInstance);
}

- (BOOL)setABLoopFromTime:(VLCTime *)from toTime:(VLCTime *)to
{
    if (from == nil || to == nil)
        return NO;

    const libvlc_time_t a_time = [[from value] longLongValue] * 1000;
    const libvlc_time_t b_time = [[to value] longLongValue] * 1000;
    return libvlc_media_player_set_abloop_time(_playerInstance, a_time, b_time) == 0;
}

- (BOOL)setABLoopFromPosition:(double)from toPosition:(double)to
{
    return libvlc_media_player_set_abloop_position(_playerInstance, from, to) == 0;
}

- (BOOL)resetABLoop
{
    return libvlc_media_player_reset_abloop(_playerInstance) == 0;
}

- (VLCMediaPlayerABLoopState)abLoopState
{
    libvlc_time_t a_time = 0, b_time = 0;
    double a_pos = 0., b_pos = 0.;
    return (VLCMediaPlayerABLoopState)libvlc_media_player_get_abloop(_playerInstance, &a_time, &a_pos, &b_time, &b_pos);
}

- (nullable VLCTime *)abLoopStartTime
{
    libvlc_time_t a_time = 0, b_time = 0;
    double a_pos = 0., b_pos = 0.;
    const libvlc_abloop_t state = libvlc_media_player_get_abloop(_playerInstance, &a_time, &a_pos, &b_time, &b_pos);
    if (state == libvlc_abloop_none)
        return nil;

    return [VLCTime timeWithNumber:@(a_time / 1000)];
}

- (nullable VLCTime *)abLoopEndTime
{
    libvlc_time_t a_time = 0, b_time = 0;
    double a_pos = 0., b_pos = 0.;
    const libvlc_abloop_t state = libvlc_media_player_get_abloop(_playerInstance, &a_time, &a_pos, &b_time, &b_pos);
    if (state != libvlc_abloop_b)
        return nil;

    return [VLCTime timeWithNumber:@(b_time / 1000)];
}

- (VLCVideoFitMode)videoFitMode
{
    return (VLCVideoFitMode)libvlc_video_get_display_fit(_playerInstance);
}

- (void)setVideoFitMode:(VLCVideoFitMode)videoFitMode
{
    libvlc_video_set_display_fit(_playerInstance, (libvlc_video_fit_mode_t)videoFitMode);
}

- (int)numberOfChaptersForTitle:(int)titleIndex
{
    if (titleIndex >= 0) {
        return libvlc_media_player_get_chapter_count_for_title(_playerInstance, titleIndex);
    }
    return 0;
}

- (NSArray<VLCMediaPlayerChapterDescription *> *)chapterDescriptionsOfTitle:(int)titleIndex
{
    NSArray<VLCMediaPlayerTitleDescription *> *titles = [self titleDescriptions];
    for (VLCMediaPlayerTitleDescription *titleDescription in titles)
        if (titleDescription.titleIndex == titleIndex)
            return titleDescription.chapterDescriptions;
    
    return @[];
}

#pragma mark -
#pragma mark Audio tracks

- (void)setAudioStereoMode:(VLCAudioStereoMode)value
{
    libvlc_audio_set_stereomode(_playerInstance, (libvlc_audio_output_stereomode_t)value);
}

- (VLCAudioStereoMode)audioStereoMode
{
    return (VLCAudioStereoMode)libvlc_audio_get_stereomode(_playerInstance);
}

- (void)setAudioMixMode:(VLCAudioMixMode)mode
{
    libvlc_audio_set_mixmode(_playerInstance, mode);
}

- (VLCAudioMixMode)audioMixMode
{
    return libvlc_audio_get_mixmode(_playerInstance);
}

- (void)setCurrentAudioPlaybackDelay:(NSInteger)index
{
    libvlc_audio_set_delay(_playerInstance, index);
}

- (NSInteger)currentAudioPlaybackDelay
{
    return libvlc_audio_get_delay(_playerInstance);
}

#pragma mark -
#pragma mark equalizer

- (void)setEqualizer:(nullable VLCAudioEqualizer *)equalizer
{
    if (_equalizer)
        [_equalizer setMediaPlayer: nil];
    
    _equalizer = equalizer;
    
    if (_equalizer)
        [_equalizer setMediaPlayer: self];
}

#pragma mark -
#pragma mark set/get media

- (void)setMedia:(nullable VLCMedia *)value
{
    if (_media != value) {
        if (_media && [_media compare:value] == NSOrderedSame)
            return;

        _media = value;

        libvlc_media_player_set_media(_playerInstance, [_media libVLCMediaDescriptor]);
    }
}

- (nullable VLCMedia *)media
{
    return _media;
}

#pragma mark -
#pragma mark playback

#if !TARGET_OS_IPHONE
- (void)preventDisplaySleep
{
    if (displaySleepAssertion != 0)
        return;

    IOReturn result = IOPMAssertionCreateWithName(
        kIOPMAssertionTypeNoDisplaySleep,
        kIOPMAssertionLevelOn,
        CFSTR("VLC Media Playback"),
        &displaySleepAssertion
    );

    if (result != kIOReturnSuccess) {
        NSLog(@"[VLCMediaPlayer] Failed to create display sleep assertion: %d", result);
    }
}

- (void)allowDisplaySleep
{
    if (displaySleepAssertion == 0)
        return;

    IOReturn result = IOPMAssertionRelease(displaySleepAssertion);
    if (result != kIOReturnSuccess) {
        NSLog(@"[VLCMediaPlayer] Failed to release display sleep assertion: %d", result);
    }
    displaySleepAssertion = 0;
}
#endif

- (void)timeChangeUpdate {
    __block BOOL isChangeValid = YES;
    dispatch_sync(_timeChangeLockQueue, ^{
        if ( _lastTimePoint.ts_us == -1 ||
            _timeDiscontinuityState ) {
            isChangeValid = NO;
            return;
        }
        
        int64_t system_now_us = _systemDateOfDiscontinuity > 0 ? _systemDateOfDiscontinuity : libvlc_clock();

        libvlc_media_player_time_point_interpolate(&_lastTimePoint,
                                                   system_now_us,
                                                   &_lastInterpolatedTime,
                                                   &_lastInterpolatedPosition);
    });
    if(!isChangeValid)
        return;

    [self willChangeValueForKey:@"time"];
    [self willChangeValueForKey:@"remainingTime"];
    [self didChangeValueForKey:@"remainingTime"];
    [self didChangeValueForKey:@"time"];

    NSNotification *notification = [NSNotification notificationWithName: VLCMediaPlayerTimeChangedNotification object: self];
    [[NSNotificationCenter defaultCenter] postNotification: notification];
    if ([self.delegate respondsToSelector:@selector(mediaPlayerTimeChanged:)])
        [self.delegate mediaPlayerTimeChanged: notification];

    [self willChangeValueForKey:@"position"];
    [self didChangeValueForKey:@"position"];
}

- (void)startTimeChangeUpdateTimer {
    [self stopTimeChangeUpdateTimer];
    __weak VLCMediaPlayer *weak_player = self;
    _timeChangeUpdateTimer = [NSTimer timerWithTimeInterval:_timeChangeUpdateInterval repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weak_player timeChangeUpdate];
    }];
    CFRunLoopRef runloop = CFRunLoopGetMain();
    CFRunLoopAddTimer(runloop, (__bridge CFRunLoopTimerRef)_timeChangeUpdateTimer, kCFRunLoopDefaultMode);
}

- (void)stopTimeChangeUpdateTimer {
    CFRunLoopRef runloop = CFRunLoopGetMain();
    if (_timeChangeUpdateTimer && CFRunLoopContainsTimer(runloop, (__bridge CFRunLoopTimerRef)_timeChangeUpdateTimer, kCFRunLoopDefaultMode)) {
        [_timeChangeUpdateTimer fire];
        CFRunLoopRemoveTimer(runloop, (__bridge CFRunLoopTimerRef)_timeChangeUpdateTimer, kCFRunLoopDefaultMode);
    }
}


- (void)play
{
    dispatch_async(_libVLCBackgroundQueue, ^{
        libvlc_media_player_play(_playerInstance);
    });
}

- (void)pause
{
    // Pause the stream
    dispatch_async(_libVLCBackgroundQueue, ^{
        libvlc_media_player_set_pause(_playerInstance, 1);
    });
}

- (void)stop
{
    libvlc_media_player_stop_async(_playerInstance);
}

- (libvlc_video_viewpoint_t *)viewPoint
{
    if (_viewpoint == NULL) {
        _viewpoint = libvlc_video_new_viewpoint();
    }
    return _viewpoint;
}

- (BOOL)updateViewpoint:(float)yaw pitch:(float)pitch roll:(float)roll fov:(float)fov absolute:(BOOL)absolute
{
    if ([self viewPoint]) {
        [self viewPoint]->f_yaw = yaw;
        [self viewPoint]->f_pitch = pitch;
        [self viewPoint]->f_roll = roll;
        [self viewPoint]->f_field_of_view = fov;

        return libvlc_video_update_viewpoint(_playerInstance, _viewpoint, absolute) == 0;
    }
    return NO;
}

- (float)yaw
{
    if ([self viewPoint]) {
        return [self viewPoint]->f_yaw;
    }
    return 0;
}

- (float)pitch
{
    if ([self viewPoint]) {
        return [self viewPoint]->f_pitch;
    }
    return 0;
}

- (float)roll
{
    if ([self viewPoint]) {
        return [self viewPoint]->f_roll;
    }
    return 0;
}

- (float)fov
{
    if ([self viewPoint]) {
        return [self viewPoint]->f_field_of_view;
    }
    return 0;
}

- (void)gotoNextFrame
{
    libvlc_media_player_next_frame(_playerInstance);
}

- (void)gotoPreviousFrame
{
    libvlc_media_player_previous_frame(_playerInstance);
}

- (void)fastForward
{
    [self fastForwardAtRate: 2.0];
}

- (void)fastForwardAtRate:(float)rate
{
    [self setRate:rate];
}

- (void)rewind
{
    [self rewindAtRate: 2.0];
}

- (void)rewindAtRate:(float)rate
{
    [self setRate: -rate];
}

- (void)jumpWithOffset:(int)interval {
    [self jumpWithOffset:interval completion:nil];
}

- (BOOL)jumpWithOffset:(int)interval completion:(dispatch_block_t)completion {
    if (![self isSeekable])
        return NO;

    self.onSeekCompletion = completion;
    int currentTime = [[self time] intValue];
    int targetTime = (currentTime + interval);
    VLCTime *newTime = [VLCTime timeWithInt: targetTime];
    [self setTime: newTime];
    return YES;
}

- (void)jumpBackward:(double)interval
{
    [self jumpWithOffset:-( (int)(interval * 1e3) )];
}

- (void)jumpForward:(double)interval
{
    [self jumpWithOffset:( (int)(interval * 1e3) )];
}

- (void)extraShortJumpBackward
{
    [self jumpBackward:3];
}

- (void)extraShortJumpForward
{
    [self jumpForward:3];
}

- (void)shortJumpBackward
{
    [self jumpBackward:10];
}

- (void)shortJumpForward
{
    [self jumpForward:10];
}

- (void)mediumJumpBackward
{
    [self jumpBackward:60];
}

- (void)mediumJumpForward
{
    [self jumpForward:60];
}

- (void)longJumpBackward
{
    [self jumpBackward:300];
}

- (void)longJumpForward
{
    [self jumpForward:300];
}

- (void)performNavigationAction:(VLCMediaPlaybackNavigationAction)action
{
    libvlc_media_player_navigate(_playerInstance, action);
}

+ (NSSet *)keyPathsForValuesAffectingIsPlaying
{
    return [NSSet setWithObjects:@"state", nil];
}

- (BOOL)isPlaying
{
    return libvlc_media_player_is_playing(_playerInstance);
}

- (VLCMediaPlayerState)state
{
    return _cachedState;
}

- (double)position
{
    __block double position;
    dispatch_sync(_timeChangeLockQueue, ^{
        position = _lastInterpolatedPosition;
    });
    
    return position;
}

- (void)setPosition:(double)newPosition
{
    libvlc_media_player_set_position(_playerInstance, newPosition, NO);
}

- (BOOL)isSeeking
{
    __block BOOL isSeeking = NO;
    dispatch_sync(_timeChangeLockQueue, ^{
        isSeeking = _isSeeking;
    });
    return isSeeking;
}

- (void)setSeeking:(BOOL)seeking {
    if (self.isSeeking == seeking)
        return;
    [self willChangeValueForKey:@"isSeeking"];
    dispatch_sync(_timeChangeLockQueue, ^{
        _isSeeking = seeking;
    });
    [self didChangeValueForKey:@"isSeeking"];
}

- (dispatch_block_t)onSeekCompletion
{
    __block dispatch_block_t onSeekCompletion;
    dispatch_sync(_timeChangeLockQueue, ^{
        onSeekCompletion = _onSeekCompletion;
    });
    return onSeekCompletion;
}

- (void)setOnSeekCompletion:(dispatch_block_t)onSeekCompletion {
    if (self.onSeekCompletion == onSeekCompletion)
        return;
    dispatch_sync(_timeChangeLockQueue, ^{
        _onSeekCompletion = onSeekCompletion;
    });
}

- (BOOL)isSeekable
{
    return libvlc_media_player_is_seekable(_playerInstance);
}

- (BOOL)canPause
{
    return libvlc_media_player_can_pause(_playerInstance);
}

- (void)mediaPlayerCapabilitiesChanged
{
    [self willChangeValueForKey:@"seekable"];
    [self willChangeValueForKey:@"canPause"];
    [self didChangeValueForKey:@"canPause"];
    [self didChangeValueForKey:@"seekable"];
}

- (nullable NSArray *)snapshots
{
    if (!_snapshots)
        return nil;
    
    return [_snapshots copy];
}

#if TARGET_OS_IPHONE
- (nullable UIImage *)lastSnapshot {
    if (_snapshots == nil) {
        return nil;
    }

    @synchronized(_snapshots) {
        if (_snapshots.count == 0)
            return nil;

        return [UIImage imageWithContentsOfFile:[_snapshots lastObject]];
    }
}
#else
- (nullable NSImage *)lastSnapshot {
    if (_snapshots == nil) {
        return nil;
    }

    @synchronized(_snapshots) {
        if (_snapshots.count == 0)
            return nil;

        return [[NSImage alloc] initWithContentsOfFile:[_snapshots lastObject]];
    }
}
#endif

- (void *)libVLCMediaPlayer
{
    return _playerInstance;
}

- (VLCEventsHandler *)eventsHandler
{
    return _eventsHandler;
}

- (void)startRecordingAtPath:(NSString *)path
{
    libvlc_media_player_record(_playerInstance, YES, [path UTF8String]);
}

- (void)stopRecording
{
    libvlc_media_player_record(_playerInstance, NO, nil);
}


#pragma mark -
#pragma mark - Renderer
#if !TARGET_OS_TV
- (BOOL)setRendererItem:(VLCRendererItem *)item
{
    return libvlc_media_player_set_renderer(_playerInstance, item.libVLCRendererItem) == 0;
}
#endif // !TARGET_OS_TV
@end

@implementation VLCMediaPlayer (Private)
- (instancetype)initWithDrawable:(id)aDrawable options:(NSArray *)options
{
    if (self = [self initCommon]) {
        _cachedState = VLCMediaPlayerStateStopped;
        _libVLCBackgroundQueue = [self libVLCBackgroundQueue];
        _minimalWatchTimePeriod = 500000;

        // Create a media instance, it doesn't matter what library we start off with
        // it will change depending on the media descriptor provided to the media
        // instance
        if (options && options.count > 0) {
            VKLog(@"creating player instance with private library as options were given");
            _privateLibrary = [[VLCLibrary alloc] initWithOptions:options];
        } else {
            VKLog(@"creating player instance using shared library");
            _privateLibrary = [VLCLibrary sharedLibrary];
        }

        static const struct libvlc_media_player_cbs cbs = {
            .version = 0,
            .on_state_changed = HandleMediaInstanceStateChanged,
            .on_buffering_changed = HandleMediaPlayerBuffering,
            .on_capabilities_changed = HandleMediaPlayerCapabilitiesChanged,
            .on_length_changed = HandleMediaPlayerLengthChanged,
            .on_track_list_changed = HandleMediaPlayerTrackChanged,
            .on_track_selection_changed = HandleMediaPlayerTrackSelectionChanged,
            .on_media_changed = HandleMediaPlayerMediaChanged,
            .on_media_meta_changed = HandleMediaPlayerMediaMetaChanged,
            .on_media_subitems_changed = HandleMediaPlayerMediaSubItemsChanged,
            .on_media_attachments_added = HandleMediaPlayerMediaAttachmentsAdded,
            .on_title_selection_changed = HandleMediaTitleSelectionChanged,
            .on_titles_changed = HandleMediaTitleListChanged,
            .on_chapter_selection_changed = HandleMediaChapterChanged,
            .on_program_list_changed = HandleMediaProgramListChanged,
            .on_program_selection_changed = HandleMediaProgramSelectionChanged,
            .on_screenshot_taken = HandleMediaPlayerSnapshot,
            .on_recording_changed = HandleMediaPlayerRecord,
            .on_audio_volume_changed = HandleMediaPlayerAudioVolumeChanged,
            .on_next_frame_status = HandleMediaPlayerNextFrameStatus,
            .on_prev_frame_status = HandleMediaPlayerPreviousFrameStatus,
        };
        _playerInstance = libvlc_media_player_new([_privateLibrary instance],
                                                  &cbs, (__bridge void *)_eventsHandler);
        if (_playerInstance == NULL) {
            NSAssert(0, @"%s: player initialization failed", __PRETTY_FUNCTION__);
            return nil;
        }

        static const struct libvlc_media_player_watch_time_cbs watch_time_cbs = {
            .version = 0,
            .on_update = HandleWatchTimeUpdate,
            .on_paused = HandleWatchTimeDiscontinuity,
            .on_seek = HandleWatchTimeOnSeek,
        };

        libvlc_media_player_watch_time(_playerInstance, _minimalWatchTimePeriod,
                                       &watch_time_cbs, (__bridge void *)_eventsHandler);

        [self setDrawable:aDrawable];
    }
    return self;
}

- (dispatch_queue_t)libVLCBackgroundQueue
{
    if (!_libVLCBackgroundQueue) {
        _libVLCBackgroundQueue = dispatch_queue_create("libvlcQueue", DISPATCH_QUEUE_SERIAL);
    }
    return  _libVLCBackgroundQueue;
}

- (void)mediaPlayerLastTimePointUpdated:(const libvlc_media_player_time_point_t)newTimePoint
{
    if (self.isSeeking)
        return;
    dispatch_sync(_timeChangeLockQueue, ^{
        _timeDiscontinuityState = NO;
        _systemDateOfDiscontinuity = 0;
        _lastTimePoint = newTimePoint;
        _lastInterpolatedTime = newTimePoint.ts_us;
        _lastInterpolatedPosition = newTimePoint.position;
    });
}

- (void)mediaPlayerHandleTimeDiscontinuity:(int64_t)systemDate
{
    dispatch_sync(_timeChangeLockQueue, ^{
        _systemDateOfDiscontinuity = systemDate;
    });
    [self timeChangeUpdate];
    dispatch_sync(_timeChangeLockQueue, ^{
        _timeDiscontinuityState = YES;
    });
}

- (void)mediaPlayerStateChanged:(const VLCMediaPlayerState)newState
{
    [self willChangeValueForKey:@"state"];
    _cachedState = newState;

    if (newState == VLCMediaPlayerStatePlaying) {
        [self startTimeChangeUpdateTimer];
#if !TARGET_OS_IPHONE
        [self preventDisplaySleep];
#endif
    } else {
        [self stopTimeChangeUpdateTimer];
#if !TARGET_OS_IPHONE
        [self allowDisplaySleep];
#endif
    }
    
    [self didChangeValueForKey:@"state"];
}

- (void)mediaPlayerMediaChanged:(VLCMedia *)newMedia
{
    [self willChangeValueForKey:@"media"];
    if (_media != newMedia) {
        _media = newMedia;

        [self willChangeValueForKey:@"time"];
        [self willChangeValueForKey:@"remainingTime"];
        [self willChangeValueForKey:@"position"];
        [self didChangeValueForKey:@"position"];
        [self didChangeValueForKey:@"remainingTime"];
        [self didChangeValueForKey:@"time"];
    }

    [self didChangeValueForKey:@"media"];
}

- (void)mediaPlayerTitleSelectionChanged:(const int)newTitle
{
    [self willChangeValueForKey:@"currentTitleIndex"];
    [self didChangeValueForKey:@"currentTitleIndex"];
}

- (void)mediaPlayerTitleListChanged:(NSString *)string
{
    [self willChangeValueForKey:@"titleDescriptions"];
    [self didChangeValueForKey:@"titleDescriptions"];
}

- (void)mediaPlayerChapterChanged:(NSNumber *)newChapter
{
    [self willChangeValueForKey:@"currentChapterIndex"];
    [self didChangeValueForKey:@"currentChapterIndex"];
}

- (void)mediaPlayerSnapshot:(NSString *)fileName
{
    @synchronized(_snapshots) {
        if (!_snapshots) {
            _snapshots = [NSMutableArray array];
        }

        [_snapshots addObject:fileName];
    }
}

@end

#pragma mark - VLCMediaPlayer+Tracks

/**
 * VLCMediaPlayer+Tracks
 */
@implementation VLCMediaPlayer (Tracks)

#pragma mark - Audio Tracks

- (NSArray<VLCMediaPlayerTrack *> *)audioTracks
{
    return [self _tracksForType: libvlc_track_audio];
}

#pragma mark - Video Tracks

- (NSArray<VLCMediaPlayerTrack *> *)videoTracks
{
    return [self _tracksForType: libvlc_track_video];
}

#pragma mark - Text Tracks

- (NSArray<VLCMediaPlayerTrack *> *)textTracks
{
    return [self _tracksForType: libvlc_track_text];
}

#pragma mark - Track Selection

- (void)selectTrackAtIndex:(NSInteger)index type:(VLCMediaTrackType)type
{
    libvlc_track_type_t trackType = (libvlc_track_type_t) type;
    libvlc_media_tracklist_t *tracklist = libvlc_media_player_get_tracklist(_playerInstance, trackType, false);

    if (!tracklist) {
        return;
    }

    const size_t tracklistCount = libvlc_media_tracklist_count(tracklist);
    if (index >= 0 && index < tracklistCount) {
        libvlc_media_track_t *track = libvlc_media_tracklist_at(tracklist, index);
        libvlc_media_player_select_track(_playerInstance, track);
    }

    libvlc_media_tracklist_delete(tracklist);
}

- (void)deselectAllAudioTracks
{
    libvlc_media_player_unselect_track_type(_playerInstance, libvlc_track_audio);
}

- (void)deselectAllVideoTracks
{
    libvlc_media_player_unselect_track_type(_playerInstance, libvlc_track_video);
}

- (void)selectTextTracks:(NSArray<VLCMediaPlayerTrack *> *)tracks
{
    if (tracks.count == 0) {
        [self deselectAllTextTracks];
        return;
    }
    
    libvlc_media_player_t *p_mi = _playerInstance;
    if (!p_mi)
        return;
    
    NSMutableArray<NSString *> *trackIds = [NSMutableArray arrayWithCapacity:tracks.count];
    for (VLCMediaPlayerTrack *track in tracks) {
        if (track.type == VLCMediaTrackTypeText) {
            [trackIds addObject:track.trackId];
        }
    }
    
    if (trackIds.count > 0) {
        NSString *idsString = [trackIds componentsJoinedByString:@","];
        libvlc_media_player_select_tracks_by_ids(p_mi, libvlc_track_text, idsString.UTF8String);
    }
}

- (void)deselectAllTextTracks
{
    libvlc_media_player_unselect_track_type(_playerInstance, libvlc_track_text);
}

#pragma mark - Private

- (NSArray<VLCMediaPlayerTrack *> *)_tracksForType:(const libvlc_track_type_t)type
{
    libvlc_media_tracklist_t *tracklist = libvlc_media_player_get_tracklist(_playerInstance, type, false);
    if (!tracklist)
        return @[];
    
    const size_t tracklistCount = libvlc_media_tracklist_count(tracklist);
    NSMutableArray<VLCMediaPlayerTrack *> *tracks = [NSMutableArray arrayWithCapacity: (NSUInteger)tracklistCount];
    for (size_t i = 0; i < tracklistCount; i++) {
        libvlc_media_track_t *track_t = libvlc_media_tracklist_at(tracklist, i);
        VLCMediaPlayerTrack *track = [[VLCMediaPlayerTrack alloc] initWithMediaTrack: track_t mediaPlayer: self];
        [tracks addObject: track];
    }
    libvlc_media_tracklist_delete(tracklist);
    return tracks;
}

- (libvlc_media_player_t *)playerInstance {
    return _playerInstance;
}

@end
