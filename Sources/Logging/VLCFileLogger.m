/*****************************************************************************
 * VLCFileLogger.m: [Mobile/TV]VLCKit.framework VLCFileLogger implementation
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

#import <VLCFileLogger.h>
#import <VLCLogMessageFormatter.h>

@implementation VLCFileLogger

@synthesize level;

+ (instancetype)createWithFileHandle:(NSFileHandle *)fileHandle {
    return  [[self alloc] initWithFileHandle:fileHandle];
}

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle {
    self = [super init];
    if (!self)
        return nil;
    _fileHandle = fileHandle;
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
              context:(VLCLogContext * _Nullable)context {
    NSString *formattedMessage = [_formatter formatWithMessage:message
                                                      logLevel:level
                                                       context:context];
    NSData *messageData = [formattedMessage dataUsingEncoding:NSUTF8StringEncoding];
    if (@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)) {
        [_fileHandle writeData:messageData error:nil];
    } else {
        @try {
            [_fileHandle writeData:messageData];
        } @catch (NSException *exception) {
            ///Silently fails
        }
    }
}

@end
