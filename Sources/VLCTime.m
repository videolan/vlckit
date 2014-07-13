/*****************************************************************************
 * VLCTime.m: VLCKit.framework VLCTime implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
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

#import "VLCTime.h"

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

+ (VLCTime *)timeWithNumber:(NSNumber *)aNumber
{
    return [[VLCTime alloc] initWithNumber:aNumber];
}

+ (VLCTime *)timeWithInt:(int)aInt
{
    return [[VLCTime alloc] initWithInt:aInt];
}

/* Initializers */
- (instancetype)initWithNumber:(NSNumber *)aNumber
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

- (NSNumber *)numberValue
{
    return _value;
}

- (NSString *)stringValue
{
    if (_value) {
        long long duration = [_value longLongValue] / 1000;
        long long positiveDuration = llabs(duration);
        if (positiveDuration > 3600)
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

- (NSString *)verboseStringValue
{
    if (_value) {
        long long duration = [_value longLongValue] / 1000;
        long long positiveDuration = llabs(duration);
        long hours = (long)(positiveDuration / 3600);
        long mins = (long)((positiveDuration / 60) % 60);
        long seconds = (long)(positiveDuration % 60);
        const char * remaining = duration < 0 ? " remaining" : "";
        if (hours > 0)
            return [NSString stringWithFormat:@"%ld hours %ld minutes%s", hours, mins, remaining];
        if (mins > 5)
            return [NSString stringWithFormat:@"%ld minutes%s", mins, remaining];
        if (mins > 0)
            return [NSString stringWithFormat:@"%ld minutes %ld seconds%s", mins, seconds, remaining];
        return [NSString stringWithFormat:@"%ld seconds%s", seconds, remaining];
    }

    // Return a string that represents an undefined time.
    return @"";
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

@end
