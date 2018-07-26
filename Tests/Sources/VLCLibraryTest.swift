/*****************************************************************************
 * VLCLibraryTest.swift
 *****************************************************************************
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

class VLCLibraryTest: XCTestCase {
    
    let paramKey = "VLCParams"
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: paramKey)
    }

    func testSharedLibrary() {
        XCTAssertNotNil(VLCLibrary.shared())
        XCTAssertNotNil(VLCLibrary.shared().instance)
    }
    
    func testInitWithOptions() throws {
        let customLibrary1 = try XCTAssertNotNilAndUnwrap(VLCLibrary(options: ["--verbose=1", "--avi-index=1"]))
        assertDefaultParameters()
        XCTAssertNotNil(customLibrary1.instance)
        
        UserDefaults.standard.removeObject(forKey: paramKey)
        
        let customLibrary2 = try XCTAssertNotNilAndUnwrap(VLCLibrary(options: []))
        assertDefaultParameters()
        XCTAssertNotNil(customLibrary2.instance)
    }
    
    func testInit() {
        let library = VLCLibrary()
        XCTAssertNotNil(library.instance)
        assertDefaultParameters()
    }
    
    func testDebugLoggingLevel() throws {
        let library = try XCTAssertNotNilAndUnwrap(VLCLibrary.shared())
        XCTAssertEqual(library.debugLoggingLevel, 0)
        
        let tests: [(input: Int32, expected: Int32)] = [
            (0, 0),
            (3, 3),
            (4, 4),
            (100, 0),
            (-10, 0)
        ]
        
        for (input, expected) in tests {
            library.debugLoggingLevel = input
            XCTAssertEqual(library.debugLoggingLevel, expected)
        }
    }
    
    func testDebugLogging() throws {
        let library = try XCTAssertNotNilAndUnwrap(VLCLibrary.shared())
        XCTAssertFalse(library.debugLogging)
        
        library.debugLogging = true
        XCTAssertTrue(library.debugLogging)
        
        library.debugLogging = false
        XCTAssertFalse(library.debugLogging)
    }
    
    func testLibraryDescription() throws {
        let library = try XCTAssertNotNilAndUnwrap(VLCLibrary.shared())
        
        let warn: (String) -> (String) = { desirable in
            return "Should hold a string of form \"\(desirable)\""
        }
        
        XCTAssertFalse(library.version.isEmpty, warn("3.0.4 Vetinari"))
        XCTAssertFalse(library.compiler.isEmpty, warn("InstalledDir: /Applications/Xcode.app/..."))
        XCTAssertFalse(library.changeset.isEmpty, warn("3.0.3-1-108-g7039639e6b"))
    }
}

extension VLCLibraryTest {
    func assertDefaultParameters() {
        let expected = [
            "--play-and-pause",
            "--no-color",
            "--no-video-title-show",
            "--verbose=4",
            "--no-sout-keep",
            "--vout=macosx",
            "--text-renderer=freetype",
            "--extraintf=macosx_dialog_provider",
            "--audio-resampler=soxr"
        ]
        
        let defaultParams = UserDefaults.standard.object(forKey: paramKey)
        
        #if os(macOS)
            XCTAssertEqual(defaultParams as? [String], expected)
        #else
            XCTAssertNil(defaultParams)
        #endif
    }
}
