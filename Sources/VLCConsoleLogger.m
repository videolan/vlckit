/*****************************************************************************
 * VLCConsoleLogger.m: [Mobile/TV]VLCKit.framework VLCConsoleLogger implementation
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

#import <VLCConsoleLogger.h>
#import <VLCLogMessageFormatter.h>

@implementation VLCConsoleLogger

@synthesize level;

- (instancetype)init {
    self = [super init];
    if (!self)
        return nil;
    _formatter = [VLCLogMessageFormatter new];
    return self;
}

- (void)setFormatter:(id<VLCLogMessageFormatting>)formatter {
    if (formatter == nil) {
        NSLog(@"Set a nil formatter isn't allowed, keeping previous formatter");
        return;
    }
    _formatter = formatter;
}

- (void)handleMessage:(nonnull NSString *)message
             logLevel:(VLCLogLevel)level
              context:(nullable VLCLogContext *)context {
    NSString *formattedMessage = [_formatter formatWithMessage:message
                                                      logLevel:level
                                                       context:context];
    VKLog(@"%@", formattedMessage);
}

@end
