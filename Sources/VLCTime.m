/*****************************************************************************
 * VLCTime.m: VLCKit.framework VLCTime implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007-2023 VLC authors and VideoLAN
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

#import <VLCTime.h>

@implementation VLCTime

/* Factories */
+ (VLCTime *)nullTime
{
    static VLCTime * nullTime = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nullTime = [VLCTime timeWithNumber:nil];
    });
    return nullTime;
}

+ (VLCTime *)timeWithNumber:(nullable NSNumber *)aNumber
{
    return [[VLCTime alloc] initWithNumber:aNumber];
}

+ (VLCTime *)timeWithInt:(int)aInt
{
    return [[VLCTime alloc] initWithInt:aInt];
}

+ (int64_t)clock
{
    return libvlc_clock();
}

+ (int64_t)delay:(int64_t)ts
{
    return libvlc_delay(ts);
}

/* Initializers */
- (instancetype)initWithNumber:(nullable NSNumber *)aNumber
{
    if (self = [super init]) {
        _value = aNumber;
    }
    return self;
}

- (instancetype)initWithInt:(int)aInt
{
    if (self = [super init]) {
        if (aInt)
            _value = @(aInt);
    }
    return self;
}

/* NSObject Overrides */
- (NSString *)description
{
    return self.stringValue;
}

- (NSString *)stringValue
{
    if (_value) {
        long long duration = [_value longLongValue];
        if (duration == INT_MAX || duration == INT_MIN) {
            // Return a string that represents an undefined time.
            return @"--:--";
        }
        duration = duration / 1000;
        long long positiveDuration = llabs(duration);
        if (positiveDuration >= 3600)
            return [NSString stringWithFormat:@"%s%01ld:%02ld:%02ld",
                        duration < 0 ? "-" : "",
                (long) (positiveDuration / 3600),
                (long)((positiveDuration / 60) % 60),
                (long) (positiveDuration % 60)];
        else
            return [NSString stringWithFormat:@"%s%02ld:%02ld",
                            duration < 0 ? "-" : "",
                    (long)((positiveDuration / 60) % 60),
                    (long) (positiveDuration % 60)];
    } else {
        // Return a string that represents an undefined time.
        return @"--:--";
    }
}

- (NSString *)subSecondStringValue
{
    if (_value) {
        long long duration = [_value longLongValue];
        if (duration == INT_MAX || duration == INT_MIN) {
            // Return a string that represents an undefined time.
            return @"--:--.---";
        }
        duration = duration;
        long long positiveDuration = llabs(duration);

        long hours = positiveDuration / 3600 / 1000;
        long minutes = (positiveDuration / 60 / 1000) % 60;
        long seconds = positiveDuration / 1000 % 60;
        long milliseconds = positiveDuration - ((hours * 3600 + minutes * 60 + seconds) * 1000);

        if (hours >= 1)
            return [NSString stringWithFormat:@"%s%01ld:%02ld:%02ld.%03ld",
                        duration < 0 ? "-" : "",
                    hours, minutes, seconds, milliseconds];
        else
            return [NSString stringWithFormat:@"%s%02ld:%02ld.%03ld",
                            duration < 0 ? "-" : "",
                    minutes, seconds, milliseconds];
    } else {
        // Return a string that represents an undefined time.
        return @"--:--.---";
    }
}

- (NSString *)verboseStringValue
{
    if (!_value)
        return @"";

    long long duration = [_value longLongValue] / 1000;
    long long positiveDuration = llabs(duration);
    long hours = (long)(positiveDuration / 3600);
    long mins = (long)((positiveDuration / 60) % 60);
    long seconds = (long)(positiveDuration % 60);
    BOOL remaining = duration < 0;
   
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setHour:hours];
    [components setMinute:mins];
    [components setSecond:seconds];

    NSString *verboseString = [NSDateComponentsFormatter localizedStringFromDateComponents:components unitsStyle:NSDateComponentsFormatterUnitsStyleFull];
    verboseString = remaining ? [NSString stringWithFormat:@"%@ remaining", verboseString] : verboseString;
    return [verboseString stringByReplacingOccurrencesOfString:@"," withString:@""];
}

- (NSString *)minuteStringValue
{
    if (_value) {
        long long positiveDuration = llabs([_value longLongValue]);
        long minutes = (long)(positiveDuration / 60000);
        return [NSString stringWithFormat:@"%ld", minutes];
    }
    return @"";
}

- (int)intValue
{
    if (!_value)
        return 0;
    
    return [_value intValue];
}

- (NSComparisonResult)compare:(VLCTime *)aTime
{
    NSInteger a = [_value integerValue];
    NSInteger b = [aTime.value integerValue];

    return (a > b) ? NSOrderedDescending :
        (a < b) ? NSOrderedAscending :
            NSOrderedSame;
}

- (BOOL)isEqual:(nullable id)object
{
    if (![object isKindOfClass:[VLCTime class]])
        return NO;

    return [[self description] isEqual:[object description]];
}

- (NSUInteger)hash
{
    return [[self description] hash];
}

@end
