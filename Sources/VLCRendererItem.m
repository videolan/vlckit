/*****************************************************************************
 * VLCRendererItem.m
 *****************************************************************************
 * Copyright © 2018 VLC authors, VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee<bubu@mikan.io>
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

#import <VLCRendererItem.h>

@interface VLCRendererItem()
{
    libvlc_renderer_item_t *_item;
}
@end

@implementation VLCRendererItem

- (void)dealloc
{
    if (_item) {
        libvlc_renderer_item_release(_item);
    }
}

@end

@implementation VLCRendererItem (VLCRendererItemBridging)

- (instancetype)initWithRendererItem:(void *)item
{
    self = [super init];
    if (self) {
        if (!item) {
            NSAssert(item, @"Renderer item is NULL");
            return nil;
        }

        _item = libvlc_renderer_item_hold(item);

        _name = [NSString stringWithUTF8String:libvlc_renderer_item_name(_item)];
        NSAssert(_name, @"VLCRendererItem: name is NULL");

        _type = [NSString stringWithUTF8String:libvlc_renderer_item_type(_item)];
        NSAssert(_type, @"VLCRendererItem: type is NULL");

        _iconURI = [NSString stringWithUTF8String:libvlc_renderer_item_icon_uri(_item)];
        NSAssert(_iconURI, @"VLCRendererItem: iconURI is NULL");

        _flags = libvlc_renderer_item_flags(_item);
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ - name: %@ type: %@ flags: %i", NSStringFromClass([self class]), self.name, self.type, self.flags];
}

- (void *)libVLCRendererItem
{
    return _item;
}

@end
