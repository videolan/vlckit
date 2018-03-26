/*****************************************************************************
 * VLCRendererItem+Init.h
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

#import "VLCRendererItem.h"

/**
 * VLCRendererItem internal category in order to hide the C part to the users
 */
@interface VLCRendererItem (Internal)

/**
* Initializer method to create an VLCRendererItem with an libvlc_renderer_item_t *
*
* \param renderer item
* \note This initializer is not meant to be used externally
* \return An instance of `VLCRendererItem`, can be nil
*/
- (instancetype _Nullable)initWithCItem:(libvlc_renderer_item_t * _Nonnull)item;

/**
 * Returns the C renderer item
 * \return Renderer item
 */
- (libvlc_renderer_item_t * _Nonnull)renderer_item;

@end
