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

#import <VLCLibrary.h>
#import <VLCLibVLCBridging.h>
#import <VLCConsoleLogger.h>
#import <VLCFileLogger.h>
#import <VLCEventsHandler.h>
#import <VLCEventsConfiguration.h>

/* VLC features different module lists per platform but also per architecture
 * so there is not a single slice with the same modules as the other */
#if TARGET_OS_TV

#if TARGET_OS_SIMULATOR
#if __aarch64__
# include "vlc-plugins-appletv-simulator-arm64.h"
#else
# include "vlc-plugins-appletv-simulator-x86_64.h"
#endif
#else
# include "vlc-plugins-appletv-device-arm64.h"
#endif
#endif

#if TARGET_OS_IOS
#if TARGET_OS_SIMULATOR
#if __x86_64__
# include "vlc-plugins-iphone-simulator-x86_64.h"
#elif __aarch64__
# include "vlc-plugins-iphone-simulator-arm64.h"
#else
# include "vlc-plugins-iphone-simulator-i386.h"
#endif
#else
#if __aarch64__
# include "vlc-plugins-iphone-device-arm64.h"
#else
# include "vlc-plugins-iphone-device-armv7.h"
#endif
#endif
#endif

#if TARGET_OS_OSX
#if __aarch64__
# include "vlc-plugins-macosx-device-arm64.h"
#else
# include "vlc-plugins-macosx-device-x86_64.h"
#endif
#endif

#if TARGET_OS_WATCH
#if TARGET_OS_SIMULATOR
#if __x86_64__
# include "vlc-plugins-watch-simulator-x86_64.h"
#else
# include "vlc-plugins-watch-simulator-arm64.h"
#endif
#else
#if __armv7k__
#warning armv7k
# include "vlc-plugins-watch-device-armv7k.h"
#else
# include "vlc-plugins-watch-device-arm64_32.h"
#endif
#endif
#endif

#include <vlc/vlc.h>
#include <vlc_common.h>

static void HandleMessage(void *,
                          int,
                          const libvlc_log_t *,
                          const char *,
                          va_list);

static VLCLibrary * sharedLibrary = nil;

@interface VLCLibrary()
@property (nonatomic, readonly) dispatch_queue_t logSyncQueue;
@end

@implementation VLCLibrary

static id<VLCEventsConfiguring> _sharedEventsConfiguration = nil;

+ (nullable id<VLCEventsConfiguring>)sharedEventsConfiguration
{
    return _sharedEventsConfiguration;
}

+ (void)setSharedEventsConfiguration:(nullable id<VLCEventsConfiguring>)value
{
    _sharedEventsConfiguration = value;
}

+ (void)load {
    [self setSharedEventsConfiguration:[VLCEventsDefaultConfiguration new]];
}

+ (nullable NSString *)currentErrorMessage
{
    const char * __nullable errmsg = libvlc_errmsg();
    return errmsg ? @(errmsg) : nil;
}

+ (void)setCurrentErrorMessage:(nullable NSString *)currentErrorMessage
{
    currentErrorMessage ? libvlc_printerr(currentErrorMessage.UTF8String) : libvlc_clearerr();
}

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
    _logSyncQueue = dispatch_queue_create("org.videolan.vlclibrary.logsyncqueue", DISPATCH_QUEUE_SERIAL);

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
                      @"--no-snapshot-preview",
#if !TARGET_OS_WATCH
                      @"--http-reconnect",
#endif
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

- (void)setLoggers:(NSArray< id<VLCLogging> > *)loggers {
    if (_instance == NULL)
        return;
    _loggers = [loggers copy];
    dispatch_sync(_logSyncQueue, ^{
        libvlc_log_unset(_instance);
    });
    if (_loggers.count > 0)
        libvlc_log_set(_instance, HandleMessage, (__bridge void *)(self));
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
    if (_instance != NULL) {
        dispatch_sync(_logSyncQueue, ^{
            libvlc_log_unset(_instance);
        });
        libvlc_release(_instance);
    }
}

@end

@interface VLCLogContext ()
@property (nonatomic, readwrite) uintptr_t objectId;
@property (nonatomic, readwrite) NSString *objectType;
@property (nonatomic, readwrite) NSString *module;
@property (nonatomic, readwrite, nullable) NSString *header;
@property (nonatomic, readwrite, nullable) NSString *file;
@property (nonatomic, readwrite) int line;
@property (nonatomic, readwrite, nullable) NSString *function;
@property (nonatomic, readwrite) unsigned long threadId;
@end

@implementation VLCLogContext

@end

static VLCLogLevel logLevelFromLibvlcLevel(int level) {
    switch (level)
    {
        case LIBVLC_NOTICE:
            return kVLCLogLevelInfo;
        case LIBVLC_ERROR:
            return kVLCLogLevelError;
        case LIBVLC_WARNING:
            return kVLCLogLevelWarning;
        case LIBVLC_DEBUG:
        default:
            return kVLCLogLevelDebug;
    }
}

static VLCLogContext* logContextFromLibvlcLogContext(const libvlc_log_t *ctx) {
    VLCLogContext *context = nil;
    if (ctx == NULL)
        return NULL;

    @autoreleasepool {
        context = [VLCLogContext new];
        context.objectId = ctx->i_object_id;
        context.objectType = [NSString stringWithUTF8String:ctx->psz_object_type];
        context.module = [NSString stringWithUTF8String:ctx->psz_module];
        if (ctx->psz_header != NULL)
            context.header = [NSString stringWithUTF8String:ctx->psz_header];
        if (ctx->file != NULL)
            context.file = [NSString stringWithUTF8String:ctx->file];
        context.line = ctx->line;
        if (ctx->func != NULL)
            context.function = [NSString stringWithUTF8String:ctx->func];
        context.threadId = ctx->tid;
    }
    return context;
}

static void HandleMessage(void *data,
                          int level,
                          const libvlc_log_t *ctx,
                          const char *fmt,
                          va_list args)
{
    VLCLibrary *libraryInstance = (__bridge VLCLibrary *)data;
    
    char *messageStr;
    int len = vasprintf(&messageStr, fmt, args);
    if (len == -1) {
        return;
    }
    
    NSString *message = [[NSString alloc] initWithBytesNoCopy:messageStr
                                                       length:len
                                                     encoding:NSUTF8StringEncoding
                                                 freeWhenDone:YES];
    const VLCLogLevel logLevel = logLevelFromLibvlcLevel(level);
    VLCLogContext *context = logContextFromLibvlcLogContext(ctx);
    dispatch_sync(libraryInstance.logSyncQueue, ^{
        [libraryInstance.loggers enumerateObjectsWithOptions:NSEnumerationConcurrent
                                                  usingBlock:^(id<VLCLogging>  _Nonnull logger,
                                                               NSUInteger idx,
                                                               BOOL * _Nonnull stop) {
            @autoreleasepool {
                if (logLevel > logger.level)
                    return;
                [logger handleMessage:message logLevel:logLevel context:context];
            }
        }];
    });
}
