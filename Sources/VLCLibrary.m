/*****************************************************************************
 * VLCLibrary.m: VLCKit.framework VLCLibrary implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007-2019 VLC authors and VideoLAN
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

#import "VLCLibrary.h"

#if TARGET_OS_TV
# include "vlc-plugins-AppleTV.h"
#elif TARGET_OS_IPHONE
# include "vlc-plugins-iPhone.h"
#else
# include "vlc-plugins-MacOSX.h"
#endif

#include <vlc/vlc.h>

static void HandleMessage(void *,
                          int,
                          const libvlc_log_t *,
                          const char *,
                          va_list);

static void HandleMessageForCustomTarget(void *,
                                         int,
                                         const libvlc_log_t *,
                                         const char *,
                                         va_list);

static VLCLibrary * sharedLibrary = nil;

@interface VLCLibrary()
{
    FILE *_logFileStream;
}
@end

@implementation VLCLibrary

+ (VLCLibrary *)sharedLibrary
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLibrary = [[VLCLibrary alloc] init];
    });
    return sharedLibrary;
}

+ (void *)sharedInstance
{
    return [self sharedLibrary].instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        [self prepareInstanceWithOptions:nil];
    }
    return self;
}

- (instancetype)initWithOptions:(NSArray *)options
{
    if (self = [super init]) {
        [self prepareInstanceWithOptions:options];
    }
    return self;
}

- (void)prepareInstanceWithOptions:(NSArray *)options
{
    NSArray *allOptions = options ? [[self _defaultOptions] arrayByAddingObjectsFromArray:options] : [self _defaultOptions];

    NSUInteger paramNum = 0;
    int count = (int)allOptions.count;
    const char *lib_vlc_params[count];
    while (paramNum < count) {
        lib_vlc_params[paramNum] = [allOptions[paramNum] cStringUsingEncoding:NSASCIIStringEncoding];
        paramNum++;
    }
    _instance = libvlc_new(count, lib_vlc_params);

    NSAssert(_instance, @"libvlc failed to initialize");
}

- (NSArray *)_defaultOptions
{
    NSArray *vlcParams = [[NSUserDefaults standardUserDefaults] objectForKey:@"VLCParams"];
#if TARGET_OS_IPHONE
    if (!vlcParams) {
        vlcParams = @[@"--no-color",
                      @"--no-osd",
                      @"--no-video-title-show",
                      @"--no-stats",
                      @"--no-snapshot-preview",
                      @"--http-reconnect",
#ifndef NOSCARYCODECS
#ifndef __LP64__
                      @"--avcodec-fast",
#endif
#endif
                      @"--text-renderer=freetype",
                      @"--avi-index=3",
                      @"--audio-resampler=soxr"];
    }
#else
    if (!vlcParams) {
        NSMutableArray *defaultParams = [NSMutableArray array];
        [defaultParams addObject:@"--play-and-pause"];                          // We want every movie to pause instead of stopping at eof
        [defaultParams addObject:@"--no-color"];                                // Don't use color in output (Xcode doesn't show it)
        [defaultParams addObject:@"--no-video-title-show"];                     // Don't show the title on overlay when starting to play
        [defaultParams addObject:@"--verbose=4"];                               // Let's not wreck the logs
        [defaultParams addObject:@"--no-sout-keep"];
        [defaultParams addObject:@"--vout=macosx"];                             // Select Mac OS X video output
        [defaultParams addObject:@"--text-renderer=freetype"];
        [defaultParams addObject:@"--extraintf=macosx_dialog_provider"];        // Some extra dialog (login, progress) may come up from here
        [defaultParams addObject:@"--audio-resampler=soxr"];                    // High quality resamper (will be used by default on VLC 4.0)

        [[NSUserDefaults standardUserDefaults] setObject:defaultParams forKey:@"VLCParams"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        vlcParams = defaultParams;
    }
#endif

    return vlcParams;
}

- (void)setDebugLogging:(BOOL)debugLogging
{
    if (!_instance)
        return;

    _debugLogging = debugLogging;
    
    if (debugLogging) {
        libvlc_log_set(_instance, HandleMessage, (__bridge void *)(self));
    } else {
        libvlc_log_unset(_instance);

        if (_logFileStream)
            fclose(_logFileStream);
    }
}

- (void)setDebugLoggingLevel:(int)debugLoggingLevel
{
    if (debugLoggingLevel >= 0 && debugLoggingLevel <= 4) {
        _debugLoggingLevel = debugLoggingLevel;
    } else {
        VKLog(@"Invalid debugLoggingLevel of %d provided", debugLoggingLevel);
        VKLog(@"Please provide a valid debugLoggingLevel between 0 and 4");
        VKLog(@"Defaulting debugLoggingLevel to 0 (just errors)");
        _debugLoggingLevel = 0;
    }
}

- (BOOL)setDebugLoggingToFile:(NSString * _Nonnull)filePath
{
    if (!filePath)
        return NO;

    if (!_instance)
        return NO;

    if (_debugLogging) {
        libvlc_log_unset(_instance);
    }

    if (_logFileStream) {
        fclose(_logFileStream);
    }

    _logFileStream = fopen([filePath UTF8String], "a");

    if (_logFileStream) {
        libvlc_log_set_file(_instance, _logFileStream);
        _debugLogging = YES;
        return YES;
    }

    return NO;
}

- (void)setDebugLoggingTarget:(id<VLCLibraryLogReceiverProtocol>) target
{
    if (![target respondsToSelector:@selector(handleMessage:debugLevel:)]) {
        VKLog(@"%s: target object does not implement required protocol", __func__);
        return;
    }
    _debugLoggingTarget = target;

    if (!_instance)
        return;

    if (_debugLogging) {
        libvlc_log_unset(_instance);
    }

    if (_logFileStream)
        fclose(_logFileStream);

    if (target) {
        libvlc_log_set(_instance, HandleMessageForCustomTarget, (__bridge void *)(self));
        _debugLogging = YES;
    }
}

- (NSString *)version
{
    return @(libvlc_get_version());
}

- (NSString *)compiler
{
    return @(libvlc_get_compiler());
}

- (NSString *)changeset
{
    return @(libvlc_get_changeset());
}

- (void)setHumanReadableName:(NSString *)readableName withHTTPUserAgent:(NSString *)userAgent
{
    if (_instance)
        libvlc_set_user_agent(_instance, [readableName UTF8String], [userAgent UTF8String]);
}

- (void)setApplicationIdentifier:(NSString *)identifier withVersion:(NSString *)version andApplicationIconName:(NSString *)icon
{
    if (_instance)
        libvlc_set_app_id(_instance, [identifier UTF8String], [version UTF8String], [icon UTF8String]);
}

- (void)dealloc
{
    if (_instance) {
        libvlc_log_unset(_instance);
        libvlc_release(_instance);
    }

    if (_logFileStream) {
        fclose(_logFileStream);
    }
}

@end

static void HandleMessage(void *data,
                          int level,
                          const libvlc_log_t *ctx,
                          const char *fmt,
                          va_list args)
{
    VLCLibrary *libraryInstance = (__bridge VLCLibrary *)data;

    if (level > libraryInstance.debugLoggingLevel)
        return;

    char *str = NULL;
    if (vasprintf(&str, fmt, args) == -1) {
        if (str)
            free(str);
        return;
    }

    if (str == NULL)
        return;

    VKLog(@"%s", str);
    free(str);
}

static void HandleMessageForCustomTarget(void *data,
                                         int level,
                                         const libvlc_log_t *ctx,
                                         const char *fmt,
                                         va_list args)
{
    VLCLibrary *libraryInstance = (__bridge VLCLibrary *)data;
    id debugLoggingTarget = libraryInstance.debugLoggingTarget;

    if (!debugLoggingTarget) {
        return;
    }

    char *str = NULL;
    if (vasprintf(&str, fmt, args) == -1) {
        if (str)
            free(str);
        return;
    }

    if (str == NULL)
        return;

    NSString *message = [[NSString alloc] initWithBytesNoCopy:str length:strlen(str) encoding:NSUTF8StringEncoding freeWhenDone:YES];

    [debugLoggingTarget handleMessage:message debugLevel:level];
}
