/*****************************************************************************
 * VLCLogMessageFormatter.m: [Mobile/TV]VLCKit.framework VLCLogMessageFormatter implementation
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

#import "VLCLogMessageFormatter.h"

@implementation VLCLogMessageFormatter

@synthesize contextFlags = _contextFlags, customContext = _customContext;

- (const NSString *)prefixFromLevel:(VLCLogLevel)level {
    switch (level)
    {
        case kVLCLogLevelInfo:
            return @"INF";
        case kVLCLogLevelError:
            return @"ERR";
        case kVLCLogLevelWarning:
            return @"WARN";
        case kVLCLogLevelDebug:
        default:
            return @"DBG";
    }
}

- (void)setCustomContext:(id)customContext {
    if (customContext)
        _contextFlags |= kVLCLogLevelContextCustom;
    _customContext = customContext;
}

- (NSString *)contextDescription:(VLCLogContext *)context {
    if (_contextFlags == kVLCLogLevelContextNone)
        return @"";
    NSString *messageContext = [NSString new];
    if (_contextFlags & kVLCLogLevelContextModule)
        messageContext = [messageContext stringByAppendingFormat:@" [%@/%@]", context.module, context.objectType];
    if (_contextFlags & kVLCLogLevelContextFileLocation)
        messageContext = [messageContext stringByAppendingFormat:@" [%@:%d]", context.file, context.line];
    if (_contextFlags & kVLCLogLevelContextCallingFunction)
        messageContext = [messageContext stringByAppendingFormat:@" [from %@]", context.function];
    if (_contextFlags & kVLCLogLevelContextCustom && _customContext && [_customContext respondsToSelector:@selector(description)])
        messageContext = [messageContext stringByAppendingFormat:@" [%@]", [_customContext description]];
    return messageContext;
}

- (nonnull NSString *)formatWithMessage:(nonnull NSString *)message
                               logLevel:(VLCLogLevel)level
                                context:(nullable VLCLogContext *)context { 
    return [NSString stringWithFormat:@"[%@] %@%@\n",
            [self prefixFromLevel:level],
            message,
            [self contextDescription:context]];
}

@end
