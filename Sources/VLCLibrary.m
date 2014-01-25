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
static void * sharedInstance = nil;

@interface VLCLibrary()
{
    void *instance;
}

@end

@implementation VLCLibrary
+ (VLCLibrary *)sharedLibrary
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLibrary = [[self alloc] init];
        sharedInstance = sharedLibrary.instance;
    });
    return sharedLibrary;
}

- (id)init
{
    if (self = [super init]) {
        NSArray *vlcParams = [self _defaultOptions];

        NSUInteger paramNum = 0;
        NSUInteger count = [vlcParams count];
        const char *lib_vlc_params[count];
        while (paramNum < count) {
            NSString *vlcParam = vlcParams[paramNum];
            lib_vlc_params[paramNum] = [vlcParam cStringUsingEncoding:NSASCIIStringEncoding];
            paramNum++;
        }
        unsigned argc = sizeof(lib_vlc_params)/sizeof(lib_vlc_params[0]);
        instance = libvlc_new(argc, lib_vlc_params);
        libvlc_retain(instance);
        NSAssert(instance, @"libvlc failed to initialize");
    }
    return self;
}

- (id)initWithOptions:(NSArray*)options
{
    if (self = [super init]) {
        NSArray *vlcParams = [self _defaultOptions];

        NSUInteger paramNum = 0;
        NSUInteger count = [vlcParams count];
        NSUInteger optionsCount = [options count];
        const char *lib_vlc_params[count+optionsCount];

        /* add default stuff */
        while (paramNum < count) {
            NSString *vlcParam = vlcParams[paramNum];
            lib_vlc_params[paramNum] = [vlcParam cStringUsingEncoding:NSASCIIStringEncoding];
            paramNum++;
        }

        /* add requested options */
        NSUInteger optionNum = 0;
        while (optionNum < optionsCount) {
            NSString *vlcParam = options[optionNum];
            lib_vlc_params[paramNum + optionNum] = [vlcParam cStringUsingEncoding:NSASCIIStringEncoding];
            optionNum++;
        }
        unsigned argc = sizeof(lib_vlc_params)/sizeof(lib_vlc_params[0]);
        instance = libvlc_new(argc, lib_vlc_params);
        libvlc_retain(instance);
        NSAssert(instance, @"libvlc failed to initialize");
    }
    return self;
}

- (NSArray *)_defaultOptions
{
    NSArray *vlcParams;
#if TARGET_OS_IPHONE
    vlcParams = @[@"--no-color",
                  @"--no-osd",
                  @"--no-video-title-show",
                  @"--no-stats",
                  @"--avcodec-fast",
                  @"--verbose=0",
                  @"--text-renderer=quartztext"];
#else
    vlcParams = [[NSUserDefaults standardUserDefaults] objectForKey:@"VLCParams"];
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
    if (instance)
        libvlc_set_user_agent(instance, [readableName UTF8String], [userAgent UTF8String]);
}

- (void)setApplicationIdentifier:(NSString *)identifier withVersion:(NSString *)version andApplicationIconName:(NSString *)icon
{
    if (instance)
        libvlc_set_app_id(instance, [identifier UTF8String], [version UTF8String], [icon UTF8String]);
}

- (void)dealloc
{
    if (instance)
        libvlc_release(instance);

    if (self == sharedLibrary) {
        sharedLibrary = nil;
        libvlc_release(sharedInstance);
        sharedInstance = nil;
    }

    [super dealloc];
}

@end

@implementation VLCLibrary (VLCLibVLCBridging)
+ (void *)sharedInstance
{
    NSAssert(sharedInstance, @"shared library doesn't have an instance");

    return sharedInstance;
}

- (void *)instance
{
    NSAssert(instance, @"library doesn't have an instance");

    return instance;
}
@end

