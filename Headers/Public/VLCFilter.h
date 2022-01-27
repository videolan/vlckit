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

#ifndef VLCFilter_h
#define VLCFilter_h

NS_ASSUME_NONNULL_BEGIN

@class VLCMediaPlayer;

/**
 * The filter value type protocol where any value should be convertible to float, int or string
 */
NS_SWIFT_NAME(VLCFilterParameterValueProtocol)
@protocol VLCFilterParameterValue <NSObject>

@property (readonly) float floatValue;
@property (readonly) int intValue;
@property (readonly, copy) NSString *stringValue;

@end

/**
 * A convenience filter parameter value type
 */
@interface VLCFilterParameterValue : NSObject <VLCFilterParameterValue>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/**
 * Default initializer
 * \param value Any value that should respond to floatValue, intValue and stringValue selectors.
 * NSString* or NSNumber* are perfect candidates here.
 * If the parameter can't respond to any selector, any value returned for the VLCFilterParameterValue protocol
 * conformance will be zero or an empty string.
 */
- (instancetype)initWithValue:(id)value NS_DESIGNATED_INITIALIZER;

@end

@protocol VLCFilter;

/**
 * An object get/set a filter parameter's value, get its default value and allowed values range
 */
NS_SWIFT_NAME(VLCFilterParameterProtocol)
@protocol VLCFilterParameter <NSObject>

/**
 * Get or change the current parameter value
 * A value change is automatically constrained by the minValue and maxValue range
 */
@property (nonatomic) id<VLCFilterParameterValue> value;

/**
 * The parameter's initial/reset value
 */
@property (nonatomic, readonly) id<VLCFilterParameterValue> defaultValue;

/**
 * The lowest value allowed for the parameter
 * A value change is automatically contrained by this property
 */
@property (nonatomic, readonly) id<VLCFilterParameterValue> minValue;

/**
 * The highest value allowed for the parameter
 * A value change is automatically contrained by this property
 */
@property (nonatomic, readonly) id<VLCFilterParameterValue> maxValue;

- (BOOL)isValueSetToDefault;

@end

@protocol VLCFilter <NSObject>

/**
 * Reference to the media player whom this filter is applied
 */
@property (nonatomic, weak, readonly) VLCMediaPlayer *mediaPlayer;

/**
 * Enable or disable the filter
 * Default to NO
 * This value will be automatically set to YES if any of the filter parameters' value is changed
 */
@property (nonatomic, getter=isEnabled) BOOL enabled;

/**
 * A dictionay containing all filter's parameters
 */
@property (nonatomic, readonly) NSDictionary< NSString*, id<VLCFilterParameter> > *parameters;

/**
 * Reset all filter parameters to default values only if their values have been previously changed
 * Note that calling this method won't disable the filter
 * If you want to disable the filter, you must call -[VLCAdjustFilter setEnabled:NO] explicitely
 * \return YES if parameters needed a reset
 */
- (BOOL)resetParametersIfNeeded;

/**
 *  Copy all parameters' value from another filter
 * \param anotherFilter
 */
- (void)applyParametersFrom:(id<VLCFilter>)otherFilter;

@end

/// Internal libvlc filter option index
extern NSString * const kVLCFilterParameterPropertyLibVLCFilterOptionKey;
/// Parameter's key in filter parameters collection
extern NSString * const kVLCFilterParameterPropertyParameterKey;
/// Parameter's default value
extern NSString * const kVLCFilterParameterPropertyValueKey;
/// Parameter's default value
extern NSString * const kVLCFilterParameterPropertyDefaultValueKey;
/// Parameter's min value
extern NSString * const kVLCFilterParameterPropertyMinValueKey;
/// Parameter's max value
extern NSString * const kVLCFilterParameterPropertyMaxValueKey;
/// Parameter's change action block
extern NSString * const kVLCFilterParameterPropertyValueChangeActionKey;

/**
 * An object to control a filter parameter's value, get its default value and allowed values range
 */
@interface VLCFilterParameter : NSObject<VLCFilterParameter>
+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)createWithProperties:(NSDictionary< NSString*,id > *)properties;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithProperties:(NSDictionary< NSString*,id > *)properties NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END

#endif /* VLCFilter_h */
