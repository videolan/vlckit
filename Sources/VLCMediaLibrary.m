/*****************************************************************************
 * VLCMediaLibrary.m: VLCKit.framework VLCMediaLibrary implementation
 *****************************************************************************
 * Copyright (C) 2007 Pierre d'Herbemont
 * Copyright (C) 2007, 2014 VLC authors and VideoLAN
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

#import <Cocoa/Cocoa.h>
#import "VLCMediaLibrary.h"
#import "VLCLibrary.h"
#import "VLCLibVLCBridging.h"

#include <vlc/libvlc.h>

@interface VLCMediaLibrary ()

{
    void *_mlib;
}

@property (nonatomic) dispatch_once_t once;
@property (nonatomic, readwrite, strong) VLCMediaList * allMedia;

@end

@implementation VLCMediaLibrary

+ (VLCMediaLibrary*)sharedMediaLibrary
{
    static VLCMediaLibrary * sharedMediaLibrary = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedMediaLibrary = [[VLCMediaLibrary alloc] init];
    });

    return sharedMediaLibrary;
}

- (instancetype)init
{
    if (self = [super init]) {
        _mlib = libvlc_media_library_new( [VLCLibrary sharedInstance]);
        libvlc_media_library_load( _mlib );
    }
    return self;
}

- (void)dealloc
{
    libvlc_media_library_release(_mlib);
    _mlib = nil;     // make sure that the pointer is dead
}

- (VLCMediaList *)allMedia
{
    dispatch_once(&_once, ^{
        libvlc_media_list_t * p_mlist = libvlc_media_library_media_list( _mlib );
        _allMedia = [VLCMediaList mediaListWithLibVLCMediaList:p_mlist];
        libvlc_media_list_release(p_mlist);
    });
    return _allMedia;
}

@end
