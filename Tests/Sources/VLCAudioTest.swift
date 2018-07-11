/*****************************************************************************
 * VLCAudioTest.swift
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

class VLCAudioTest: XCTestCase {
    
    let step = 6
    let min: Int32 = 0
    let max: Int32 = 200
    
    func testPassThrough() throws {
        let player = VLCMediaPlayer()
        let audio = try XCTAssertNotNilAndUnwrap(player.audio)
        
        XCTAssertFalse(audio.passthrough)
        
        audio.passthrough = true
        XCTAssertTrue(audio.passthrough)
        
        audio.passthrough = false
        XCTAssertFalse(audio.passthrough)
    }
    
    func testVolumeDown() throws {
        let player = VLCMediaPlayer()
        let audio = try XCTAssertNotNilAndUnwrap(player.audio)
        
        audio.volume = max
        XCTAssertEqual(audio.volume, max)
        
        let tests: [(repeatCount: Int, expected: Int32)] = [
            (10,  140),
            (5,   110),
            (0,   110),
            (15,  20),
            (100, min)
        ]
        
        for (repeatCount, expected) in tests {
            (0..<repeatCount).forEach { _ in audio.volumeDown() }
            XCTAssertEqual(audio.volume, expected)
        }
    }
    
    func testVolumeUp() throws {
        let player = VLCMediaPlayer()
        let audio = try XCTAssertNotNilAndUnwrap(player.audio)
        
        audio.volume = min
        XCTAssertEqual(audio.volume, 0)
        
        let tests: [(repeatCount: Int, expected: Int32)] = [
            (5,   30),
            (10,  90),
            (10,  150),
            (0,   150),
            (100, max)
        ]
        
        for (repeatCount, expected) in tests {
            (0..<repeatCount).forEach { _ in audio.volumeUp() }
            XCTAssertEqual(audio.volume, expected)
        }
    }
    
    func testSetVolume() throws {
        let player = VLCMediaPlayer()
        let audio = try XCTAssertNotNilAndUnwrap(player.audio)
        
        let tests: [(target: Int32, expected: Int32)] = [
            (min, min),
            (min - 100, min),
            (50, 50),
            (100, 100),
            (max, max),
            (max + 100, max)
        ]
        
        for (target, expected) in tests {
            audio.volume = target
            XCTAssertEqual(audio.volume, expected)
        }
    }
}
