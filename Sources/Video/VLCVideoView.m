/*****************************************************************************
 * VLCVideoView.m: VLCKit.framework VLCVideoView implementation
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

#import "VLCVideoView.h"
#import "VLCLibrary.h"
#import "VLCVideoCommon.h"

/* Libvlc */
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc/vlc.h>
#include <vlc/libvlc.h>

#import <QuartzCore/QuartzCore.h>

/******************************************************************************
 * Soon deprecated stuff
 */

/* This is a forward reference to VLCOpenGLVoutView specified in minimal_macosx
   library.  We could get rid of this, but it prevents warnings from the
   compiler. (Scheduled to deletion) */
@interface VLCOpenGLVoutView : NSView
- (void)detachFromVout;
@end

/******************************************************************************
 * VLCVideoView (Private)
 */

@interface VLCVideoView ()

@property (nonatomic, readwrite) BOOL hasVideo;
@property (nonatomic, retain) VLCVideoLayoutManager *layoutManager;

- (void)addVoutLayer:(CALayer *)aLayer;

@end

/******************************************************************************
 * Implementation VLCVideoView
 */

@implementation VLCVideoView

/* Initializers */
- (instancetype)initWithFrame:(NSRect)rect
{
    if (self = [super initWithFrame:rect])
    {
        self.backColor = [NSColor blackColor];
        self.autoresizesSubviews = YES;
        self.layoutManager = [VLCVideoLayoutManager layoutManager];
    }
    return self;
}

/* NSView Overrides */
- (void)drawRect:(NSRect)aRect
{
    [self lockFocus];
    [self.backColor set];
    NSRectFill(aRect);
    [self unlockFocus];
}

- (BOOL)isOpaque
{
    return YES;
}

- (BOOL)fillScreen
{
    return [self.layoutManager fillScreenEntirely];
}

- (void)setFillScreen:(BOOL)fillScreen
{
    [self.layoutManager setFillScreenEntirely:fillScreen];
    [self.layer setNeedsLayout];
}

/******************************************************************************
 * Implementation VLCVideoView  (Private)
 */

/* This is called by the libvlc module 'opengllayer' as soon as there is one
 * vout available
 */
- (void)addVoutLayer:(CALayer *)aLayer
{
    aLayer.name = @"vlcopengllayer";

    [CATransaction begin];

    self.wantsLayer = YES;
    CALayer * rootLayer = self.layer;

    [self.layoutManager setOriginalVideoSize:aLayer.bounds.size];
    [rootLayer setLayoutManager:self.layoutManager];
    [rootLayer insertSublayer:aLayer atIndex:0];
    [aLayer setNeedsDisplayOnBoundsChange:YES];

    [CATransaction commit];

    self.hasVideo = YES;
}

- (void)removeVoutLayer:(CALayer *)voutLayer
{
    [CATransaction begin];
    [voutLayer removeFromSuperlayer];
    [CATransaction commit];

    self.hasVideo = NO;
}

@end

