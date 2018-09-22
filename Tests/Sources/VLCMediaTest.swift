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
            (VLCMediaTracksInformationTypeAudio, 0x414B4D53, "Smacker audio"),
            (VLCMediaTracksInformationTypeVideo, 0x32564933, "3ivx MPEG-4 Video"),
            (VLCMediaTracksInformationTypeText, 0x37324353, "SCTE-27 subtitles"),
            (VLCMediaTracksInformationTypeUnknown, 0x37324353, "SCTE-27 subtitles"),
            ("", 0x0, "")
        ]
        
        for (input, fourcc, expected) in tests {
            let actual = VLCMedia.codecName(forFourCC: fourcc, trackType: input)
            XCTAssertEqual(expected, actual, input)
        }
    }
    
    func testInitWithUrl() throws {
        let tests = [
            "sftp://dummypath.mov",
            "smb://dummypath.mkv",
            "http://www.xyz.com/我们走吧.mp3".encodeURL(),
            "smb://server/가즈아.mp3".encodeURL(),
            "smb://server/media file.mp3".encodeURL()
        ]
        
        for path in tests {
            let url = try XCTAssertNotNilAndUnwrap(URL(string: path))
            let media = VLCMedia(url: url)
            XCTAssertEqual(media.url, url)
            media.verify(type: .file)
        }
    }
}

extension VLCMedia {
    func verify(type: VLCMediaType,file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(metaDictionary, file: file, line: line)
        XCTAssertNotNil(subitems, file: file, line: line)
        XCTAssertNotNil(url, file: file, line: line)
        XCTAssertEqual(mediaType, type, file: file, line: line)
        XCTAssertEqual(state, VLCMediaState.nothingSpecial, file: file, line: line)
    }
}

extension String {
    func encodeURL() -> String {
        guard let encoded = addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
            XCTFail("Failed to encode URL \(self)")
            return ""
        }
        return encoded
    }
}
