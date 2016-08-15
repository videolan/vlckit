/*****************************************************************************
 * VLCStreamOutput.h: VLCKit.framework VLCStreamOutput header
 *****************************************************************************
 * Copyright (C) 2008 Pierre d'Herbemont
 * Copyright (C) 2008, 2014 VLC authors and VideoLAN
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

/**
 * \deprecated will be removed in the next release
 */
extern NSString * VLCDefaultStreamOutputRTSP;
/**
 * \deprecated will be removed in the next release
 */
extern NSString * VLCDefaultStreamOutputRTP;
/**
 * \deprecated will be removed in the next release
 */
extern NSString * VLCDefaultStreamOutputRTP;

/**
 * a class allowing you to stream media based on predefined definitions
 */
@interface VLCStreamOutput : NSObject

/**
 * \deprecated will be removed in the next release
 */
- (instancetype)initWithOptionDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER __attribute__((deprecated));
/**
 * \deprecated will be removed in the next release
 */
+ (instancetype)streamOutputWithOptionDictionary:(NSDictionary *)dictionary __attribute__((deprecated));

/**
 * \deprecated will be removed in the next release
 */
+ (id)rtpBroadcastStreamOutputWithSAPAnnounce:(NSString *)announceName __attribute__((deprecated));
/**
 * \deprecated will be removed in the next release
 */
+ (id)rtpBroadcastStreamOutput __attribute__((deprecated));
/**
 * \deprecated will be removed in the next release
 */
+ (id)ipodStreamOutputWithFilePath:(NSString *)filePath __attribute__((deprecated));
/**
 * \deprecated will be removed in the next release
 */
+ (instancetype)streamOutputWithFilePath:(NSString *)filePath __attribute__((deprecated));
/**
 * \deprecated will be removed in the next release
 */
+ (id)mpeg2StreamOutputWithFilePath:(NSString *)filePath __attribute__((deprecated));
/**
 * \deprecated will be removed in the next release
 */
+ (id)mpeg4StreamOutputWithFilePath:(NSString *)filePath __attribute__((deprecated));

@end
