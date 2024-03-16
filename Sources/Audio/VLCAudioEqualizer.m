/*****************************************************************************
 * VLCAudioEqualizer.m: VLCKit.framework VLCAudioEqualizer implementation
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

#import <VLCAudioEqualizer.h>
#import <VLCMediaPlayer.h>
#import <VLCLibVLCBridging.h>

#include <vlc/vlc.h>

/// VLCAudioEqualizer (Internal)
@interface VLCAudioEqualizer (Internal)

@property (nonatomic, nullable, readonly) VLCAudioEqualizerPreset *preset;

- (float)amplificationForBandIndex:(unsigned)index;
- (void)setAmplification:(float)amplification bandIndex:(unsigned)index;
- (void)setLibEqualizerOnLibMediaPlayer;

@end


/// VLCAudioEqualizerPreset
@implementation VLCAudioEqualizerPreset

- (instancetype)initWithName:(NSString *)name index:(unsigned)index
{
    if (self = [super init]) {
        _name = name;
        _index = index;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>, name: %@, index: %u", self.class, self, _name, _index];
}

- (BOOL)isEqual:(id)other
{
    if (![other isKindOfClass: VLCAudioEqualizerPreset.class])
        return NO;
    
    VLCAudioEqualizerPreset *otherPreset = (VLCAudioEqualizerPreset *)other;
    return otherPreset.index == _index && [otherPreset.name isEqualToString: _name];
}

- (NSUInteger)hash
{
    return self.description.hash;
}

@end


/// VLCAudioEqualizerBand
@implementation VLCAudioEqualizerBand
{
    __weak VLCAudioEqualizer *_equalizer;
}

- (instancetype)initWithEqualizer:(VLCAudioEqualizer *)equalizer frequency:(float)frequency index:(unsigned)index
{
    if (self = [super init]) {
        _equalizer = equalizer;
        _frequency = frequency;
        _index = index;
    }
    return self;
}

- (float)amplification
{
    return [_equalizer amplificationForBandIndex: _index];
}

- (void)setAmplification:(float)amplification
{
    [_equalizer setAmplification: amplification bandIndex: _index];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>, frequency: %f, index: %u, amplification: %f", self.class, self, _frequency, _index, self.amplification];
}

- (BOOL)isEqual:(id)other
{
    if (![other isKindOfClass: VLCAudioEqualizerBand.class])
        return NO;
    
    VLCAudioEqualizerBand *otherEqualizerBand = (VLCAudioEqualizerBand *)other;
    return otherEqualizerBand.index == _index &&
    otherEqualizerBand.frequency == _frequency &&
    otherEqualizerBand.amplification == self.amplification;
}

- (NSUInteger)hash
{
    return self.description.hash;
}

@end


/// VLCAudioEqualizer
@implementation VLCAudioEqualizer
{
    __weak VLCMediaPlayer *_mediaPlayer;
    libvlc_equalizer_t *_p_equalizer;
    NSArray<VLCAudioEqualizerBand *> *_bands;
    VLCAudioEqualizerPreset * _Nullable _preset;
}

+ (NSArray<VLCAudioEqualizerPreset *> *)presets
{
    static NSArray<VLCAudioEqualizerPreset *> *presets = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const unsigned count = libvlc_audio_equalizer_get_preset_count();
        NSMutableArray<VLCAudioEqualizerPreset *> *array = [NSMutableArray arrayWithCapacity: (NSUInteger)count];
        for (unsigned index = 0; index < count; index++) {
            const char *preset_name = libvlc_audio_equalizer_get_preset_name(index) ?: "";
            VLCAudioEqualizerPreset *preset = [[VLCAudioEqualizerPreset alloc] initWithName: @(preset_name) index: index];
            [array addObject: preset];
        }
        presets = [array copy];
    });
    return presets;
}

- (instancetype)init
{
    if (self = [self initCommon]) {
        _p_equalizer = libvlc_audio_equalizer_new();
        NSAssert(_p_equalizer, @"Error equalizer failed to initialize");
    }
    return self;
}

- (instancetype)initWithPreset:(VLCAudioEqualizerPreset *)preset
{
    if (self = [self initCommon]) {
        _p_equalizer = libvlc_audio_equalizer_new_from_preset(preset.index);
        NSAssert(_p_equalizer, @"Error equalizer failed to initialize");
        _preset = preset;
    }
    return self;
}

- (instancetype)initCommon
{
    if (self = [super init]) {
        const unsigned count = libvlc_audio_equalizer_get_band_count();
        NSMutableArray<VLCAudioEqualizerBand *> *array = [NSMutableArray arrayWithCapacity: (NSUInteger)count];
        for (unsigned index = 0; index < count; index++) {
            const float frequency = libvlc_audio_equalizer_get_band_frequency(index);
            VLCAudioEqualizerBand *band = [[VLCAudioEqualizerBand alloc] initWithEqualizer: self frequency: frequency index: index];
            [array addObject: band];
        }
        _bands = [array copy];
    }
    return self;
}

- (void)setPreAmplification:(float)preAmplification
{
    const BOOL success = libvlc_audio_equalizer_set_preamp(_p_equalizer, preAmplification) == 0;
    if (!success) {
        VKLog(@"Error libvlc_audio_equalizer_set_preamp() %s", __PRETTY_FUNCTION__);
        return;
    }
    [self setLibEqualizerOnLibMediaPlayer];
}

- (float)preAmplification
{
    return libvlc_audio_equalizer_get_preamp(_p_equalizer);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>, preset: %@, preAmplification: %f, bands: %@", self.class, self, _preset, self.preAmplification, _bands.description];
}

- (BOOL)isEqual:(id)other
{
    if (![other isKindOfClass: VLCAudioEqualizer.class])
        return NO;
    
    VLCAudioEqualizer *otherEqualizer = (VLCAudioEqualizer *)other;
    return [otherEqualizer.preset isEqual: _preset] &&
    otherEqualizer.preAmplification == self.preAmplification &&
    [otherEqualizer.bands isEqualToArray: _bands];
}

- (NSUInteger)hash
{
    return self.description.hash;
}

- (void)dealloc
{
    libvlc_audio_equalizer_release(_p_equalizer);
}

@end


/// VLCAudioEqualizer (Internal)
@implementation VLCAudioEqualizer (Internal)

- (nullable VLCAudioEqualizerPreset *)preset
{
    return _preset;
}

- (float)amplificationForBandIndex:(unsigned)index
{
    return libvlc_audio_equalizer_get_amp_at_index(_p_equalizer, index);
}

- (void)setAmplification:(float)amplification bandIndex:(unsigned)index
{
    const BOOL success = libvlc_audio_equalizer_set_amp_at_index(_p_equalizer, amplification, index) == 0;
    if (!success) {
        VKLog(@"Error libvlc_audio_equalizer_set_amp_at_index() %s", __PRETTY_FUNCTION__);
        return;
    }
    [self setLibEqualizerOnLibMediaPlayer];
}

- (void)setLibEqualizerOnLibMediaPlayer
{
    libvlc_media_player_t *p_mi = _mediaPlayer.libVLCMediaPlayer;
    if (!p_mi)
        return;
    
    const BOOL success = libvlc_media_player_set_equalizer(p_mi, _p_equalizer) == 0;
    if (!success)
        VKLog(@"Error libvlc_media_player_set_equalizer() %s", __PRETTY_FUNCTION__);
}

@end


/// VLCAudioEqualizer (LibVLCBridging)
@implementation VLCAudioEqualizer (LibVLCBridging)

- (void)setMediaPlayer:(nullable VLCMediaPlayer *)mediaPlayer
{
    libvlc_media_player_t *p_mi = _mediaPlayer.libVLCMediaPlayer;
    if (p_mi && !mediaPlayer) {
        const BOOL success = libvlc_media_player_set_equalizer(p_mi, NULL) == 0;
        if (!success)
            VKLog(@"Error libvlc_media_player_set_equalizer() %s", __PRETTY_FUNCTION__);
    }
    
    _mediaPlayer = mediaPlayer;
    
    if (_mediaPlayer)
        [self setLibEqualizerOnLibMediaPlayer];
}

@end
