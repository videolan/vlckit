/*****************************************************************************
 * VLCMediaListTest.swift
 *****************************************************************************
 * Copyright (C) 2018 Mike JS. Choi
 * Copyright (C) 2018 VLC authors and VideoLAN
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

class VLCMediaListTest: XCTestCase {

    func testRemoveMedia() throws {
        let videos = [Video.test1, Video.test1, Video.test2, Video.test3, Video.test4, Video.test4]
        let source = videos.map{ $0.media }
        let mediaList = try XCTAssertNotNilAndUnwrap(VLCMediaList(array: source))
        
        let NF = UInt(NSNotFound)
        let tests: [(targetIdx: UInt, expectedState: [UInt], ok: Bool)] = [
            (0, [NF, 0, 1, 2, 3, 4], true),
            (3, [NF, 0, 1, 2,NF, 3], true),
            (9, [NF, 0, 1, 2,NF, 3], false),
            (2, [NF, 0, 1,NF,NF, 2], true),
            (1, [NF, 0,NF,NF,NF, 1], true),
            (8, [NF, 0,NF,NF,NF, 1], false),
            (0, [NF,NF,NF,NF,NF, 0], true),
            (0, [NF,NF,NF,NF,NF,NF], true),
            (6, [NF,NF,NF,NF,NF,NF], false)
        ]
        
        for (targetIdx, expectedState, ok) in tests {
            let removalResult = mediaList.removeMedia(at: targetIdx)
            let currentState = source.map{ mediaList.index(of: $0) }
            
            XCTAssertEqual(removalResult, ok)
            XCTAssertEqual(currentState, expectedState)
        }
    }
}
