/*****************************************************************************
 * VLCKit: VLCMediaThumbnailer
 *****************************************************************************
 * Copyright (C) 2010-2012 Pierre d'Herbemont and VideoLAN
 *
 * Authors: Pierre d'Herbemont
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

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
# import <CoreGraphics/CoreGraphics.h>
#endif

@class VLCMedia;
@class VLCLibrary;
@protocol VLCMediaThumbnailerDelegate;

@interface VLCMediaThumbnailer : NSObject {
    id<VLCMediaThumbnailerDelegate> _delegate;
    VLCMedia *_media;
    void *_mp;
    CGImageRef _thumbnail;
    void *_data;
    NSTimer *_parsingTimeoutTimer;
    NSTimer *_thumbnailingTimeoutTimer;

    CGFloat _thumbnailHeight,_thumbnailWidth;
    float _snapshotPosition;
    CGFloat _effectiveThumbnailHeight,_effectiveThumbnailWidth;
    int _numberOfReceivedFrames;
    BOOL _shouldRejectFrames;
}

+ (VLCMediaThumbnailer *)thumbnailerWithMedia:(VLCMedia *)media andDelegate:(id<VLCMediaThumbnailerDelegate>)delegate;
+ (VLCMediaThumbnailer *)thumbnailerWithMedia:(VLCMedia *)media delegate:(id<VLCMediaThumbnailerDelegate>)delegate andVLCLibrary:(VLCLibrary *)library;
- (void)fetchThumbnail;

@property (readwrite, assign) id<VLCMediaThumbnailerDelegate> delegate;
@property (readwrite, retain) VLCMedia *media;
@property (readwrite, assign) CGImageRef thumbnail;
@property (readwrite) void * libVLCinstance;

/**
 * Thumbnail Height
 * You shouldn't change this after -fetchThumbnail
 * has been called.
 * @return thumbnail height. Default value 240.
 */
@property (readwrite, assign) CGFloat thumbnailHeight;

/**
 * Thumbnail Width
 * You shouldn't change this after -fetchThumbnail
 * has been called.
 * @return thumbnail height. Default value 320
 */
@property (readwrite, assign) CGFloat thumbnailWidth;

/**
 * Snapshot Position
 * You shouldn't change this after -fetchThumbnail
 * has been called.
 * @return snapshot position. Default value 0.5
 */
@property (readwrite, assign) float snapshotPosition;
@end

@protocol VLCMediaThumbnailerDelegate
@required
- (void)mediaThumbnailerDidTimeOut:(VLCMediaThumbnailer *)mediaThumbnailer;
- (void)mediaThumbnailer:(VLCMediaThumbnailer *)mediaThumbnailer didFinishThumbnail:(CGImageRef)thumbnail;
@end
