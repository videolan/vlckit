/*****************************************************************************
 * VLCMediaTest.swift
 *****************************************************************************
 * Copyright (C) 2018 Mike JS. Choi
 * $Id$
 *
 * Authors: Mike JS. Choi <mkchoi212 # icloud.com>
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

import XCTest

class VLCMediaTest: XCTestCase {
    func testCodecNameForFourCC() {
        let tests: [(input: String, fourcc: UInt32, expected: String)] = [
            (VLCMediaTrackTypeAudio, 0x414B4D53, "Smacker audio"),
            (VLCMediaTrackTypeVideo, 0x32564933, "3ivx MPEG-4 Video"),
            (VLCMediaTrackTypeText, 0x37324353, "SCTE-27 subtitles"),
            (VLCMediaTrackTypeUnknown, 0x37324353, "SCTE-27 subtitles"),
            ("", 0x0, "")
        ]
        
        for (input, fourcc, expected) in tests {
            let actual = VLCMedia.codecName(forFourCC: fourcc, trackType: input)
            XCTAssertEqual(expected, actual, input)
        }
    }
}
