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
#import <VLCFilter.h>
#import <VLCFilter+Internal.h>
#import <VLCMediaPlayer+Internal.h>

/// Internal libvlc filter option index
NSString * const kVLCFilterParameterPropertyLibVLCFilterOptionKey = @"LibVLCFilterOption";
/// Parameter's key in filter parameters collection
NSString * const kVLCFilterParameterPropertyParameterKey = @"ParameterKey";
/// Parameter's default value
NSString * const kVLCFilterParameterPropertyValueKey = @"Value";
/// Parameter's default value
NSString * const kVLCFilterParameterPropertyDefaultValueKey = @"DefaultValue";
/// Parameter's min value
NSString * const kVLCFilterParameterPropertyMinValueKey = @"MinValue";
/// Parameter's max value
NSString * const kVLCFilterParameterPropertyMaxValueKey = @"MaxValue";
/// Parameter's change action block
NSString * const kVLCFilterParameterPropertyValueChangeActionKey = @"ValueChangeAction";

@implementation VLCFilterParameter {
    NSMutableDictionary<NSString *,id> *_properties;
}

//@synthesize filter = _filter;

+ (instancetype)createWithProperties:(NSDictionary<NSString *,id> *)properties {
    return [[self alloc] initWithProperties:properties];
}

- (instancetype)initWithProperties:(NSDictionary<NSString *,id> *)properties {
    if (self = [super init]) {
        _properties = properties.mutableCopy;
        _properties[kVLCFilterParameterPropertyValueKey] = [_properties[kVLCFilterParameterPropertyDefaultValueKey] copy];
    }
    return self;
}

- (id)value
{
    return _properties[kVLCFilterParameterPropertyValueKey];
}

- (void)setValue:(id)value
{
    if (![value respondsToSelector:@selector(floatValue)]) {
        @throw([NSException exceptionWithName:@"UnexpectedParameter"
                                       reason:@"Can't call [value floatValue] from [VLCFilterParameter setValue:]"
                                     userInfo:nil]);
    }
    float newValue = [value floatValue];
    float currentValue = [_properties[kVLCFilterParameterPropertyValueKey] floatValue];
    if (newValue == currentValue)
        return;
    float maxValue = [_properties[kVLCFilterParameterPropertyMaxValueKey] floatValue];
    float minValue = [_properties[kVLCFilterParameterPropertyMinValueKey] floatValue];
    newValue = MAX(MIN(newValue, maxValue), minValue);
    _properties[kVLCFilterParameterPropertyValueKey] = @(newValue);
    VLCFilterParameterValueChangeAction valueChangeAction = _properties[kVLCFilterParameterPropertyValueChangeActionKey];
    if (valueChangeAction) {
        valueChangeAction(self.value);
    }
}

- (id)defaultValue
{
    return _properties[kVLCFilterParameterPropertyDefaultValueKey];
}

- (id)minValue
{
    return _properties[kVLCFilterParameterPropertyMinValueKey];
}

- (id)maxValue
{
    return _properties[kVLCFilterParameterPropertyMaxValueKey];
}

- (BOOL)isValueSetToDefault {
    return [_properties[kVLCFilterParameterPropertyValueKey] floatValue]
    == [_properties[kVLCFilterParameterPropertyDefaultValueKey] floatValue];
}

@end
