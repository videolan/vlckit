/*****************************************************************************
 * VLCLibrary.m: VLCKit.framework VLCLibrary implementation
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

#import "VLCLibrary.h"
#import "VLCLibVLCBridging.h"

#if TARGET_OS_IPHONE
# include "vlc-plugins.h"
#endif

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc/vlc.h>
#include <vlc/libvlc_structures.h>

static VLCLibrary * sharedLibrary = nil;

@interface VLCLibrary()

@property (nonatomic, assign) void *instance;

@end

@implementation VLCLibrary

+ (VLCLibrary *)sharedLibrary
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLibrary = [[self alloc] init];
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

- (instancetype)initWithOptions:(NSArray*)options
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
    if (_instance)
        libvlc_retain(_instance);

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
#ifndef NOSCARYCODECS
                      @"--avcodec-fast",
#endif
                      @"--verbose=0",
                      @"--text-renderer=quartztext",
                      @"--avi-index=3",
                      @"--extraintf=ios_dialog_provider"];
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
        [defaultParams addObject:@"--text-renderer=quartztext"];                // our CoreText-based renderer
        [defaultParams addObject:@"--extraintf=macosx_dialog_provider"];        // Some extra dialog (login, progress) may come up from here

        [[NSUserDefaults standardUserDefaults] setObject:defaultParams forKey:@"VLCParams"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        vlcParams = defaultParams;
    }
#endif

    return vlcParams;
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
    if (_instance)
        libvlc_release(_instance);
}

@end
