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

#if TARGET_OS_TV
# include "vlc-plugins-AppleTV.h"
#elif TARGET_OS_IPHONE
# include "vlc-plugins-iPhone.h"
#else
# include "vlc-plugins-MacOSX.h"
#endif

#ifdef HAVE_CONFIG_H
# include "config.h"
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
{
    FILE *_logFileStream;
    
}
@property (nonatomic, readonly) dispatch_queue_t logSyncQueue;
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
    _logContextFlags = kVLCLogLevelContextNone;
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
    [self changeLoggingOutput:kVLCLogOutputConsole];
}

- (BOOL)debugLogging {
    return _logOutput != kVLCLogOutputDisabled;
}

- (BOOL)changeLoggingOutput:(VLCLogOutput)logOutput {
    if (!_instance)
        return NO;
    dispatch_sync(_logSyncQueue, ^{
        libvlc_log_unset(_instance);
    });
    if (_logFileStream)
        fclose(_logFileStream);
    _logFileStream = NULL;
    switch (logOutput) {
        case kVLCLogOutputDisabled: {
            _logOutput = logOutput;
            break;
        }
        case kVLCLogOutputFile: {
            if (self.loggingFilePath == nil) {
                return NO;
            }
            
            _logFileStream = fopen([self.loggingFilePath UTF8String], "a");

            if (!_logFileStream) {
                return NO;
            }
            libvlc_log_set_file(_instance, _logFileStream);
            break;
        }
        case kVLCLogOutputExternalHandler:
            if (self.loggingExternalHandler == nil) {
                return NO;
            }
        case kVLCLogOutputConsole:
        default:
            libvlc_log_set(_instance, HandleMessage, (__bridge void *)(self));
            break;
    }
    _logOutput = logOutput;
    return YES;
}

- (void)setDebugLoggingLevel:(int)debugLoggingLevel
{
    debugLoggingLevel = MAX(0, MIN(debugLoggingLevel, 3));
    _logLevel = debugLoggingLevel;
}

- (int)debugLoggingLevel {
    return (int)_logLevel;
}

- (BOOL)setDebugLoggingToFile:(NSString * _Nonnull)filePath
{
    return [self enableLoggingToFile:filePath];
}

- (BOOL)enableLoggingToFile:(NSString * _Nonnull)filePath {
    _loggingFilePath = filePath;
    if (![self changeLoggingOutput:kVLCLogOutputFile]) {
        _loggingFilePath = nil;
    }
    return _loggingFilePath != nil;
}

- (void)setDebugLoggingTarget:(nullable id<VLCLibraryLogReceiverProtocol>) target
{
    [self enableLoggingWithExternalHandler:target];
}

- (BOOL)enableLoggingWithExternalHandler:(id<VLCLibraryLogReceiverProtocol>)loggingExternalHandler {
    _loggingExternalHandler = loggingExternalHandler;
    if (![self changeLoggingOutput:kVLCLogOutputExternalHandler]) {
        _loggingExternalHandler = nil;
    }
    return _loggingExternalHandler != nil;
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
        dispatch_sync(_logSyncQueue, ^{
            libvlc_log_unset(_instance);
        });
        libvlc_release(_instance);
    }

    if (_logFileStream) {
        fclose(_logFileStream);
    }
}

@end

@interface VLCLogContext ()
@property (nonatomic, readwrite) uintptr_t objectId;
@property (nonatomic, readwrite) NSString *objectType;
@property (nonatomic, readwrite) NSString *module;
@property (nonatomic, readwrite) NSString *header;
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

static const char* logLevelPrefixFromLevel(VLCLogLevel level) {
    switch (level)
    {
        case kVLCLogLevelInfo:
            return "INF";
        case kVLCLogLevelError:
            return "ERR";
        case kVLCLogLevelWarning:
            return "WARN";
        case kVLCLogLevelDebug:
        default:
            return "DBG";
    }
}

static VLCLogContext* logContextFromLibvlcLogContext(const libvlc_log_t *ctx) {
    VLCLogContext *context = nil;
    if (ctx) {
        context = [VLCLogContext new];
        context.objectId = ctx->i_object_id;
        context.objectType = [NSString stringWithUTF8String:ctx->psz_object_type];
        context.module = [NSString stringWithUTF8String:ctx->psz_module];
        context.header = [NSString stringWithUTF8String:ctx->psz_header];
        if (ctx->file)
            context.file = [NSString stringWithUTF8String:ctx->file];
        context.line = ctx->line;
        if (ctx->func)
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
    dispatch_sync(libraryInstance.logSyncQueue, ^{
        @autoreleasepool {
            const VLCLogLevel logLevel = logLevelFromLibvlcLevel(level);
            
            if (logLevel > libraryInstance.logLevel)
                return;

            char *messageStr;
            if (vasprintf(&messageStr, fmt, args) == -1) {
                if (messageStr) {
                    free(messageStr);
                }
                return;
            }

            NSString *message = [[NSString alloc] initWithBytesNoCopy:messageStr
                                                               length:strlen(messageStr)
                                                             encoding:NSUTF8StringEncoding
                                                         freeWhenDone:YES];
            
            if (libraryInstance.logOutput == kVLCLogOutputExternalHandler) {
                id<VLCLibraryLogReceiverProtocol> handler = libraryInstance.loggingExternalHandler;
                if (!handler) {
                    return;
                }
                VLCLogContext *context = logContextFromLibvlcLogContext(ctx);
                if ([handler respondsToSelector:@selector(handleMessage:debugLevel:)])
                    [handler handleMessage:message
                                debugLevel:logLevel];
                if ([handler respondsToSelector:@selector(handleMessage:logLevel:context:)])
                    [handler handleMessage:message
                                  logLevel:logLevel
                                   context:context];
            } else {
                const char *log_prefix = logLevelPrefixFromLevel(logLevel);
                if (libraryInstance.logContextFlags != kVLCLogLevelContextNone) {
                    VLCLogContext *context = logContextFromLibvlcLogContext(ctx);
                    NSString *contextMessage = [NSString new];
                    if (libraryInstance.logContextFlags | kVLCLogLevelContextModule)
                        contextMessage = [contextMessage stringByAppendingFormat:@" [%@]", context.module];
                    if (libraryInstance.logContextFlags | kVLCLogLevelContextFileLocation)
                        contextMessage = [contextMessage stringByAppendingFormat:@" [%@:%d]", context.file, context.line];
                    if (libraryInstance.logContextFlags | kVLCLogLevelContextCallingFunction)
                        contextMessage = [contextMessage stringByAppendingFormat:@" [from %@]", context.function];
                    VKLog(@"[%s] %s%@)", log_prefix, messageStr, contextMessage);
                } else {
                    VKLog(@"[%s] %s", log_prefix, messageStr);
                }
            }
        }
    });
}
