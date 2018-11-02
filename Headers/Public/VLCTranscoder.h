/*****************************************************************************
* VLCTranscoder.h
*****************************************************************************
* Copyright © 2018 VLC authors, VideoLAN
* Copyright © 2018 Videolabs
*
* Authors: Carola nitz<caro@videolan.org>
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

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides an object to convert a subtitle file and moviefile into one.
 */
@interface VLCTranscoder : NSObject

/**
 * mux srt and mp4 file to an mp4 file with embedded subtitles
 * \param srtPath path to srt file
 * \param mp4Path path to mp4 file
 * \param outPath path where the new file should be written to
 * \return an BOOL with the success status, returns NO if the subtitle file is not an srt or mp4File is not an mp4 file
 */
- (BOOL)muxSubtitleFile:(NSString *)srtPath toMp4File:(NSString *)mp4Path outputPath:(NSString *)outPath;

@end

NS_ASSUME_NONNULL_END
