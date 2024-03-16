/*****************************************************************************
 * VLCMediaPlayerTitleDescription.m: VLCKit.framework VLCMediaPlayerTitleDescription implementation
 *****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
 * $Id$
 *
 * Authors:
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

#import <VLCMediaPlayerTitleDescription.h>
#import <VLCTime.h>
#import <VLCMediaPlayer.h>
#import <VLCLibVLCBridging.h>
#include <vlc/vlc.h>

#pragma mark - VLCMediaPlayerChapterDescription

/**
 * VLCMediaPlayerChapterDescription
 */
@implementation VLCMediaPlayerChapterDescription
{
    __weak VLCMediaPlayer *_mediaPlayer;
}

- (BOOL)isCurrent
{
    if (![_mediaPlayer.media.url isEqual: _mediaURL])
        return NO;
    
    libvlc_media_player_t *p_mi = _mediaPlayer.libVLCMediaPlayer;
    if (!p_mi)
        return NO;
    
    const int title_count = libvlc_media_player_get_title_count(p_mi);
    if (title_count == -1)
        return NO;
    
    const int current_title = libvlc_media_player_get_title(p_mi);
    if (current_title == -1 || current_title != _titleIndex)
        return NO;
    
    const int chapter_count = libvlc_media_player_get_chapter_count(p_mi);
    if (chapter_count == -1)
        return NO;
    
    const int current_chapter = libvlc_media_player_get_chapter(p_mi);
    if (current_chapter == -1)
        return NO;
    
    return current_chapter == _chapterIndex;
}

- (void)setCurrent
{
    if (![_mediaPlayer.media.url isEqual: _mediaURL])
        return;
    
    libvlc_media_player_t *p_mi = _mediaPlayer.libVLCMediaPlayer;
    if (!p_mi)
        return;
    
    const int title_count = libvlc_media_player_get_title_count(p_mi);
    if (title_count == -1)
        return;
    
    const int current_title = libvlc_media_player_get_title(p_mi);
    if (current_title == -1)
        return;
    
    if (current_title != _titleIndex)
        libvlc_media_player_set_title(p_mi, _titleIndex);
    
    libvlc_media_player_set_chapter(p_mi, _chapterIndex);
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    else if (![other isKindOfClass: self.class])
        return NO;
    
    VLCMediaPlayerChapterDescription *otherChapterDescription = (VLCMediaPlayerChapterDescription *)other;
    return [otherChapterDescription.mediaURL isEqual: _mediaURL] &&
            otherChapterDescription.titleIndex == _titleIndex &&
            otherChapterDescription.chapterIndex == _chapterIndex &&
            [otherChapterDescription.name isEqualToString: _name] &&
            [otherChapterDescription.durationTime isEqual: _durationTime] &&
            [otherChapterDescription.timeOffset isEqual: _timeOffset];
}

- (NSUInteger)hash
{
    return self.description.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"<%@ %p>, mediaURL: %@, titleIndex: %d, name: %@, durationTime: %@, timeOffset: %@, chapterIndex: %d", self.class, self, _mediaURL, _titleIndex, _name, _durationTime, _timeOffset, _chapterIndex];
}

@end

/**
 * VLCMediaPlayerChapterDescription (LibVLCBridging)
 */
@implementation VLCMediaPlayerChapterDescription (LibVLCBridging)

- (instancetype)initWithMediaPlayer:(VLCMediaPlayer *)mediaPlayer titleIndex:(const int)titleIndex chapterDescription:(libvlc_chapter_description_t *)chapter_description chapterIndex:(const int)chapterIndex
{
    if (self = [super init]) {
        _mediaPlayer = mediaPlayer;
        _name = chapter_description->psz_name ? @(chapter_description->psz_name) : nil;
        _timeOffset = [VLCTime timeWithNumber: @(chapter_description->i_time_offset)];
        _durationTime = [VLCTime timeWithNumber: @(chapter_description->i_duration)];
        _chapterIndex = chapterIndex;
        _titleIndex = titleIndex;
        _mediaURL = mediaPlayer.media.url;
    }
    return self;
}

@end


#pragma mark - VLCMediaPlayerTitleDescription

/**
 * VLCMediaPlayerTitleDescription
 */
@implementation VLCMediaPlayerTitleDescription
{
    __weak VLCMediaPlayer *_mediaPlayer;
}

- (BOOL)isCurrent
{
    if (![_mediaPlayer.media.url isEqual: _mediaURL])
        return NO;
    
    libvlc_media_player_t *p_mi = _mediaPlayer.libVLCMediaPlayer;
    if (!p_mi)
        return NO;
    
    const int title_count = libvlc_media_player_get_title_count(p_mi);
    if (title_count == -1)
        return NO;
    
    const int current_title = libvlc_media_player_get_title(p_mi);
    if (current_title == -1)
        return NO;
    
    return current_title == _titleIndex;
}

- (void)setCurrent
{
    if (![_mediaPlayer.media.url isEqual: _mediaURL])
        return;
    
    libvlc_media_player_t *p_mi = _mediaPlayer.libVLCMediaPlayer;
    if (!p_mi)
        return;
    
    libvlc_media_player_set_title(p_mi, _titleIndex);
}

- (void)navigateActivate
{
    [self navigate: libvlc_navigate_activate];
}

- (void)navigateUp
{
    [self navigate: libvlc_navigate_up];
}

- (void)navigateDown
{
    [self navigate: libvlc_navigate_down];
}

- (void)navigateLeft
{
    [self navigate: libvlc_navigate_left];
}

- (void)navigateRight
{
    [self navigate: libvlc_navigate_right];
}

- (void)navigatePopup
{
    [self navigate: libvlc_navigate_popup];
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    else if (![other isKindOfClass: self.class])
        return NO;
    
    VLCMediaPlayerTitleDescription *otherTitleDescription = (VLCMediaPlayerTitleDescription *)other;
    return [otherTitleDescription.mediaURL isEqual: _mediaURL] &&
            otherTitleDescription.titleIndex == _titleIndex &&
            otherTitleDescription.titleType == _titleType &&
            [otherTitleDescription.name isEqualToString: _name] &&
            [otherTitleDescription.durationTime isEqual: _durationTime] &&
            [otherTitleDescription.chapterDescriptions isEqual: _chapterDescriptions];
}

- (NSUInteger)hash
{
    return self.description.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"<%@ %p>, mediaURL: %@, name: %@, durationTime: %@, titleType: %u, titleIndex: %d, isMenu: %@, chapterDescriptions: %@", self.class, self, _mediaURL, _name, _durationTime, _titleType, _titleIndex, _menu ? @"YES" : @"NO", _chapterDescriptions];
}

@end

/**
 * VLCMediaPlayerTitleDescription (LibVLCBridging)
 */
@implementation VLCMediaPlayerTitleDescription (LibVLCBridging)

- (instancetype)initWithMediaPlayer:(VLCMediaPlayer *)mediaPlayer titleDescription:(libvlc_title_description_t *)title_description titleIndex:(const int)titleIndex
{
    if (self = [super init]) {
        _mediaPlayer = mediaPlayer;
        _name = title_description->psz_name ? @(title_description->psz_name) : nil;
        _durationTime = [VLCTime timeWithNumber: @(title_description->i_duration)];
        _titleType = (VLCMediaPlayerTitleType)title_description->i_flags;
        _titleIndex = titleIndex;
        _mediaURL = mediaPlayer.media.url;
        _menu = title_description->i_flags & libvlc_title_menu;
        
        libvlc_chapter_description_t **pp_chapters = NULL;
        const int count = libvlc_media_player_get_full_chapter_descriptions(mediaPlayer.libVLCMediaPlayer, titleIndex, &pp_chapters);
        if (count == -1)
            _chapterDescriptions = @[];
        else if (count == 0) {
            libvlc_chapter_descriptions_release(pp_chapters, count);
            _chapterDescriptions = @[];
        }else{
            NSMutableArray<VLCMediaPlayerChapterDescription *> *array = [NSMutableArray arrayWithCapacity: (NSUInteger)count];
            for (int i = 0; i < count; i++) {
                VLCMediaPlayerChapterDescription *chapterDescription = [[VLCMediaPlayerChapterDescription alloc] initWithMediaPlayer: mediaPlayer titleIndex: titleIndex chapterDescription: pp_chapters[i] chapterIndex: i];
                [array addObject: chapterDescription];
            }
            libvlc_chapter_descriptions_release(pp_chapters, count);
            _chapterDescriptions = [array copy];
        }
    }
    return self;
}

- (void)navigate:(const libvlc_navigate_mode_t)navigate_mode
{
    if (![_mediaPlayer.media.url isEqual: _mediaURL] || !_menu)
        return;
    
    libvlc_media_player_t *p_mi = _mediaPlayer.libVLCMediaPlayer;
    if (!p_mi)
        return;
    
    libvlc_media_player_navigate(p_mi, navigate_mode);
}

@end
