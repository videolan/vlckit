/*****************************************************************************
 * VLCMediaThumbnailerTest.swift
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

class MockThumbnailerDelegate: NSObject, VLCMediaThumbnailerDelegate {
    
    var timedOutExpectation: XCTestExpectation?
    var finishedExpectation: XCTestExpectation?
    
    func mediaThumbnailerDidTimeOut(_ mediaThumbnailer: VLCMediaThumbnailer!) {
        timedOutExpectation?.fulfill()
    }
    
    func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer!, didFinishThumbnail thumbnail: CGImage!) {
        finishedExpectation?.fulfill()
    }
    
}

class VLCMediaThumbnailerTest: XCTestCase {
    
    // MARK: Initializers
    
    func testInitWithMediaAndDelegate() throws {
        let tests = Video.standards.map{ $0.media }
        
        for media in tests {
            let delegate = MockThumbnailerDelegate()
            let thumbnailer = try XCTAssertNotNilAndUnwrap(VLCMediaThumbnailer(media: media, andDelegate: delegate))
            
            XCTAssertNil(thumbnailer.thumbnail)
            XCTAssertNotNil(thumbnailer.delegate)
            XCTAssertEqual(thumbnailer.media, media)
            XCTAssertEqual(thumbnailer.libVLCinstance, VLCLibrary.shared().instance)
        }
    }
    
    func testInitWithMediaDelegateAndLibrary() throws {
        let sharedLibrary = VLCLibrary.shared()
        let customLibrary = VLCLibrary(options: [])
        
        let tests: [(library: VLCLibrary?, expected: VLCLibrary?)] = [
            (sharedLibrary, sharedLibrary),
            (customLibrary, customLibrary),
            (nil, sharedLibrary)
        ]
        
        for (library, expected) in tests {
            let delegate = MockThumbnailerDelegate()
            let media = Video.test1.media
            let thumbnailer = try XCTAssertNotNilAndUnwrap(VLCMediaThumbnailer(media: media, delegate: delegate, andVLCLibrary: library))
            
            XCTAssertNil(thumbnailer.thumbnail)
            XCTAssertNotNil(thumbnailer.delegate)
            XCTAssertEqual(thumbnailer.media, media)
            XCTAssertEqual(thumbnailer.libVLCinstance, expected?.instance)
        }
    }
    
    func testFetchThumbnail() throws {
        
        let skipMediaParse: (XCTestExpectation) -> (VLCMedia) = { expectation in
            expectation.fulfill()
            return Video.test1.media
        }
        
        let completeMediaParse: (XCTestExpectation) -> (VLCMedia) = { expectation in
            let media = Video.test1.media
            media.lengthWait(until: Date.distantFuture)
            expectation.fulfill()
            return media
        }
        
        let tests: [(parseFunc: ((XCTestExpectation) -> (VLCMedia)), expectation: XCTestExpectation)] = [
            (skipMediaParse, expectation(description: "Skipped parsing media")),
            (completeMediaParse, expectation(description: "Completed parsing media"))
        ]
        
        for (parseFunc, parseExpectation) in tests {
            let media = parseFunc(parseExpectation)
            wait(for: [parseExpectation], timeout: STANDARD_TIME_OUT)
            
            let delegate = MockThumbnailerDelegate()
            let fetched = expectation(description: "delegate::didFinishThumbnail called")
            delegate.finishedExpectation = fetched
            
            let thumbnailer = try XCTAssertNotNilAndUnwrap(VLCMediaThumbnailer(media: media, andDelegate: delegate))
            thumbnailer.fetchThumbnail()
            
            wait(for: [fetched], timeout: STANDARD_TIME_OUT)
            
            XCTAssertNotNil(thumbnailer.thumbnail)
            XCTAssertEqual(thumbnailer.thumbnailWidth, 417)
            XCTAssertEqual(thumbnailer.thumbnailHeight, 240)
            XCTAssertEqual(thumbnailer.snapshotPosition, 0.3)
        }
    }
    
    // MARK: Delegate callbacks
    
    func testDelegateDidFinishThumbnail() throws {
        
        let tests: [(video: Video, width: CGFloat, height: CGFloat)] = [
            (Video.test1, 417, 240),
            (Video.test2, 427, 240),
            (Video.test3, 427, 240),
            (Video.test4, 427, 240)
        ]
        
        for (video, width, height) in tests {
            let delegate = MockThumbnailerDelegate()
            let fetched = expectation(description: "delegate::didFinishThumbnail called")
            delegate.finishedExpectation = fetched

            let thumbnailer = try XCTAssertNotNilAndUnwrap(VLCMediaThumbnailer(media: video.media, andDelegate: delegate))
            thumbnailer.fetchThumbnail()

            wait(for: [fetched], timeout: STANDARD_TIME_OUT)

            XCTAssertNotNil(thumbnailer.thumbnail)
            XCTAssertEqual(thumbnailer.thumbnailWidth, width)
            XCTAssertEqual(thumbnailer.thumbnailHeight, height)
            XCTAssertEqual(thumbnailer.snapshotPosition, 0.3)
        }
    }
    
    func testDelegateMediaThumbnailerDidTimeOut() throws {
        let media = Video.invalid
        let delegate = MockThumbnailerDelegate()
        let timedOut = expectation(description: "delegate::mediaThumbnailerDidTimeOut called")
        delegate.timedOutExpectation = timedOut
        
        let thumbnailer = try XCTAssertNotNilAndUnwrap(VLCMediaThumbnailer(media: media.media, andDelegate: delegate))
        thumbnailer.fetchThumbnail()
        
        let internalWaitDuration = 10.0
        wait(for: [timedOut], timeout: internalWaitDuration + STANDARD_TIME_OUT)
        
        XCTAssertNil(thumbnailer.thumbnail)
        XCTAssertEqual(thumbnailer.thumbnailWidth, 0)
        XCTAssertEqual(thumbnailer.thumbnailHeight, 0)
    }
    
    func testCustomThumbnailOptions() throws {
        
        let tests: [(video: Video, height: CGFloat, width: CGFloat, position: Float)] = [
            (Video.test1, 320, 184, 0.5),
            (Video.test2, 327, 184, 0.6),
            (Video.test3, 500, 281, 0.7),
            (Video.test4, 711, 400, 0.8)
        ]
        
        for (video, width, height, position) in tests {
            let delegate = MockThumbnailerDelegate()
            let fetched = expectation(description: "delegate::didFinishThumbnail called")
            delegate.finishedExpectation = fetched
            
            let thumbnailer = try XCTAssertNotNilAndUnwrap(VLCMediaThumbnailer(media: video.media, andDelegate: delegate))
            thumbnailer.thumbnailWidth = width
            thumbnailer.thumbnailHeight = height
            thumbnailer.snapshotPosition = position
            
            thumbnailer.fetchThumbnail()
            wait(for: [fetched], timeout: STANDARD_TIME_OUT)
            
            XCTAssertNotNil(thumbnailer.thumbnail)
            XCTAssertEqual(thumbnailer.thumbnailWidth, width)
            XCTAssertEqual(thumbnailer.thumbnailHeight, height)
            XCTAssertEqual(thumbnailer.snapshotPosition, position)
        }
    }
}
