/*****************************************************************************
 * VLCFilter.h: VLCKit.framework VLCFilter header
 *****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Maxime Chapelet <umxprime # videolabs.io>
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
#import <vlc/vlc.h>
#import <VLCAdjustFilter.h>
#import <VLCFilter+Internal.h>
#import <VLCMediaPlayer+Internal.h>

NSString * const kVLCAdjustFilterContrastParameterKey = @"Contrast";
NSString * const kVLCAdjustFilterBrightnessParameterKey = @"Brightness";
NSString * const kVLCAdjustFilterHueParameterKey = @"Hue";
NSString * const kVLCAdjustFilterSaturationParameterKey = @"Saturation";
NSString * const kVLCAdjustFilterGammaParameterKey = @"Gamma";

@implementation VLCAdjustFilter {
    NSMutableDictionary< NSString*, id<VLCFilterParameter> > *_parameters;
    BOOL _enabled;
}

@synthesize mediaPlayer = _mediaPlayer;

+ (NSDictionary<NSString *,id> *)contrastProperties {
    return @{
        kVLCFilterParameterPropertyLibVLCFilterOptionKey : @(libvlc_adjust_Contrast),
        kVLCFilterParameterPropertyParameterKey : kVLCAdjustFilterContrastParameterKey,
        kVLCFilterParameterPropertyDefaultValueKey : @(1.f),
        kVLCFilterParameterPropertyMinValueKey : @(0.f),
        kVLCFilterParameterPropertyMaxValueKey : @(2.f)
    };
}

+ (NSDictionary<NSString *,id> *)brightnessProperties {
    return @{
        kVLCFilterParameterPropertyLibVLCFilterOptionKey : @(libvlc_adjust_Brightness),
        kVLCFilterParameterPropertyParameterKey : kVLCAdjustFilterBrightnessParameterKey,
        kVLCFilterParameterPropertyDefaultValueKey : @(1.f),
        kVLCFilterParameterPropertyMinValueKey : @(0.f),
        kVLCFilterParameterPropertyMaxValueKey : @(2.f)
    };
}

+ (NSDictionary<NSString *,id> *)hueProperties {
    return @{
        kVLCFilterParameterPropertyLibVLCFilterOptionKey : @(libvlc_adjust_Hue),
        kVLCFilterParameterPropertyParameterKey : kVLCAdjustFilterHueParameterKey,
        kVLCFilterParameterPropertyDefaultValueKey : @(0.f),
        kVLCFilterParameterPropertyMinValueKey : @(-180.f),
        kVLCFilterParameterPropertyMaxValueKey : @(180.f)
    };
}

+ (NSDictionary<NSString *,id> *)saturationProperties {
    return @{
        kVLCFilterParameterPropertyLibVLCFilterOptionKey : @(libvlc_adjust_Saturation),
        kVLCFilterParameterPropertyParameterKey : kVLCAdjustFilterSaturationParameterKey,
        kVLCFilterParameterPropertyDefaultValueKey : @(1.f),
        kVLCFilterParameterPropertyMinValueKey : @(0.f),
        kVLCFilterParameterPropertyMaxValueKey : @(3.f)
    };
}

+ (NSDictionary<NSString *,id> *)gammaProperties {
    return @{
        kVLCFilterParameterPropertyLibVLCFilterOptionKey : @(libvlc_adjust_Gamma),
        kVLCFilterParameterPropertyParameterKey : kVLCAdjustFilterGammaParameterKey,
        kVLCFilterParameterPropertyDefaultValueKey : @(1.f),
        kVLCFilterParameterPropertyMinValueKey : @(0.01f),
        kVLCFilterParameterPropertyMaxValueKey : @(10.f)
    };
}

+ (instancetype)createWithVLCMediaPlayer:(VLCMediaPlayer *)mediaPlayer
{
    return [[self alloc] initWithVLCMediaPlayer:mediaPlayer];
}

- (instancetype)initWithVLCMediaPlayer:(VLCMediaPlayer *)mediaPlayer {
    if (self = [super init]) {
        _mediaPlayer = mediaPlayer;
        _parameters = [NSMutableDictionary new];
        [self appendParameterWithProperties:[self.class contrastProperties]];
        [self appendParameterWithProperties:[self.class brightnessProperties]];
        [self appendParameterWithProperties:[self.class hueProperties]];
        [self appendParameterWithProperties:[self.class saturationProperties]];
        [self appendParameterWithProperties:[self.class gammaProperties]];
    }
    return self;
}

- (void)appendParameterWithProperties:(NSDictionary<NSString *,id> *)properties {
    NSMutableDictionary *extendedProperties = properties.mutableCopy;
    __weak VLCAdjustFilter *weakSelf = self;
    enum libvlc_video_adjust_option_t option = [properties[kVLCFilterParameterPropertyLibVLCFilterOptionKey] intValue];
    extendedProperties[kVLCFilterParameterPropertyValueChangeActionKey] = ^(id newValue){
        weakSelf.enabled = YES;
        libvlc_video_set_adjust_float(weakSelf.mediaPlayer.playerInstance, option, [newValue floatValue]);
    };
    NSString *key = properties[kVLCFilterParameterPropertyParameterKey];
    _parameters[key] = [VLCFilterParameter createWithProperties:extendedProperties];
}

- (NSDictionary< NSString*, id<VLCFilterParameter> > *)parameters
{
    return _parameters;
}

- (id<VLCFilterParameter>)contrast
{
    return _parameters[kVLCAdjustFilterContrastParameterKey];
}

- (id<VLCFilterParameter>)brightness
{
    return _parameters[kVLCAdjustFilterBrightnessParameterKey];
}

- (id<VLCFilterParameter>)hue
{
    return _parameters[kVLCAdjustFilterHueParameterKey];
}

- (id<VLCFilterParameter>)saturation
{
    return _parameters[kVLCAdjustFilterSaturationParameterKey];
}

- (id<VLCFilterParameter>)gamma
{
    return _parameters[kVLCAdjustFilterGammaParameterKey];
}

- (BOOL)isEnabled
{
    return _enabled;
}
- (void)setEnabled:(BOOL)enabled
{
    if (enabled == _enabled)
        return;

    _enabled = enabled;
    libvlc_video_set_adjust_int(_mediaPlayer.playerInstance, libvlc_adjust_Enable, enabled);
}

- (BOOL)areParametersSetToDefault
{
    __block BOOL result = YES;
    [_parameters enumerateKeysAndObjectsUsingBlock:
     ^(NSString * _Nonnull key, id<VLCFilterParameter>  _Nonnull obj, BOOL * _Nonnull stop) {
        if (![obj isValueSetToDefault]) {
            result = NO;
            *stop = YES;
        }
    }];
    return result;
}

- (BOOL)resetParametersIfNeeded
{
    if (self.areParametersSetToDefault) {
        return NO;
    }

    BOOL enabled = self.isEnabled;
    [_parameters enumerateKeysAndObjectsUsingBlock:
     ^(NSString * _Nonnull key, id<VLCFilterParameter>  _Nonnull obj, BOOL * _Nonnull stop) {
        obj.value = obj.defaultValue;
    }];
    self.enabled = enabled;
    return YES;
}

- (void)applyParametersFrom:(id<VLCFilter>)otherFilter {
    if (otherFilter == nil)
        return;
    BOOL enabled = self.isEnabled;
    [_parameters enumerateKeysAndObjectsUsingBlock:
     ^(NSString * _Nonnull key, id<VLCFilterParameter>  _Nonnull obj, BOOL * _Nonnull stop) {
        id<VLCFilterParameter> otherParameter = otherFilter.parameters[key];
        if (otherParameter) {
            obj.value = otherParameter.value;
        }
    }];
    self.enabled = enabled;
}

@end
