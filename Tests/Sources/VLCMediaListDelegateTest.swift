/*****************************************************************************
 * VLCMediaListDelegateTest.swift
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

final class MockMediaListDelegate: NSObject, VLCMediaListDelegate {
    var removedIdx: UInt?
    var removedExpectation: XCTestExpectation?
    
    func mediaList(_ aMediaList: VLCMediaList!, mediaRemovedAt index: UInt) {
        removedIdx = index
        removedExpectation?.fulfill()
    }
}

class VLCMediaListDelegateTest: XCTestCase {
    
    // MARK: Delegate callbacks
    
    func testMediaRemovedAt() throws {
        let videos = [Video.test1, Video.test2, Video.test3, Video.test4]
        let source = videos.map{ VLCMedia(path: $0.path) }
        let mediaList = try XCTAssertNotNilAndUnwrap(VLCMediaList(array: source))
        
        let delegate = MockMediaListDelegate()
        mediaList.delegate = delegate
        
        for idx in stride(from: UInt(source.count - 1), to: 0, by: -1) {
            let delegateCalled = expectation(description: "delegate::mediaRemovedAt called")
            delegate.removedExpectation = delegateCalled
            
            let oldCount = mediaList.count
            
            // Remove media from list
            let ok = mediaList.removeMedia(at: idx)
            XCTAssertTrue(ok)
            
            wait(for: [delegateCalled], timeout: STANDARD_TIME_OUT)
            
            XCTAssertEqual(delegate.removedIdx, idx)
            XCTAssertEqual(mediaList.count, oldCount - 1)
        }
    }
    
    // MARK: Notification

    func testMediaItemDeletedNotification() throws {
        let tests: [(deleteIdx: UInt, count: Int, removalSuccessful: Bool)] = [
            (9,  4, false),
            (3,  3, true),
            (1,  2, true),
            (99, 2, false),
            (1,  1, true),
            (0,  0, true),
            (10, 0, false),
        ]
        
        let videos = [Video.test1, Video.test2, Video.test3, Video.test4]
        let source = videos.map{ VLCMedia(path: $0.path) }
        let mediaList = try XCTAssertNotNilAndUnwrap(VLCMediaList(array: source))

        for (deleteIdx, count, removalSuccessful) in tests {
            let removalResult = mediaList.removeMedia(at: deleteIdx)
            XCTAssertEqual(removalResult, removalSuccessful)
            
            if removalSuccessful {
                let deleteNotification = NSNotification.Name(rawValue: VLCMediaListItemDeleted)
                let internalListChanged = expectation(forNotification: deleteNotification, object: mediaList) { notification in
                    guard let idx = notification.userInfo?["index"] as? NSNumber else {
                        return false
                    }
                    return idx.int64Value == deleteIdx && mediaList.count == count
                }
                
                wait(for: [internalListChanged], timeout: STANDARD_TIME_OUT)
            }
        }
    }
}
