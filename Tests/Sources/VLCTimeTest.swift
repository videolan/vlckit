/*****************************************************************************
 * VLCTimeTest.swift
 *****************************************************************************
 * Copyright (C) 2018 VLC authors and VideoLAN
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

struct TimeResult {
    let value: NSNumber?
    let string: String
    let verboseString: String
    let minuteString: String
    let intValue: Int32
    
    func assertEqual(_ time: VLCTime, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(time.value, value, file: file, line: line)
        XCTAssertEqual(time.stringValue, string, file: file, line: line)
        XCTAssertEqual(time.verboseStringValue, verboseString, file: file, line: line)
        XCTAssertEqual(time.minuteStringValue, minuteString, file: file, line: line)
        XCTAssertEqual(time.intValue, intValue, file: file, line: line)
    }
}

class VLCTimeTest: XCTestCase {
    // MARK: Init
    func testNullTime() {
        guard let nullTime = VLCTime.null() else {
            XCTFail("Could not initialize null VLCTime")
            return
        }
        
        let expected = TimeResult(value: nil, string: "--:--", verboseString: "", minuteString: "", intValue: 0)
        expected.assertEqual(nullTime)
    }
    
    func testInitializers() {
        let testTime: Int32 = 100000
        
        guard let timeFromInt = VLCTime(int: testTime) else {
            XCTFail("Could not initialize VLCTime with int")
            return
        }
        
        let expected = TimeResult(value: NSNumber(value: testTime), string: "01:40", verboseString: "1 minute 40 seconds", minuteString: "1", intValue: testTime)
        expected.assertEqual(timeFromInt)
    }
    
    func testInitWithNumber() {
        let testTime: Int32 = 100000
        
        guard let timeFromNumber = VLCTime(number: NSNumber(value: testTime)) else {
            XCTFail("Could not initialize VLCTime with NSNumber")
            return
        }
        
        let expected = TimeResult(value: NSNumber(value: testTime), string: "01:40", verboseString: "1 minute 40 seconds", minuteString: "1", intValue: testTime)
        expected.assertEqual(timeFromNumber)
    }
    
    // MARK: String representations
    func testStringConversion(_ tests: [(Int32, String)], assert: (VLCTime, String) -> ()) {
        for (milliseconds, expected) in tests {
            guard let time = VLCTime(int: milliseconds) else {
                XCTFail("Could not initialize VLCTime with int \(milliseconds) ms")
                return
            }
            assert(time, expected)
        }
    }
    
    func testTimeToStringDescription() {
        let tests: [(time: Int32, expected: String)] = [
            (-10000, "-00:10"),
            (10000, "00:10"),
            (70000, "01:10"),
            (3630000, "1:00:30"),
            (15650000, "4:20:50")
        ]
        testStringConversion(tests) { (time, expected) in
            XCTAssertEqual(time.description, expected)
        }
    }
    
    func testTimeToVerboseString() {
        let tests: [(time: Int32, expected: String)] = [
            (-10000, "10 seconds remaining"),
            (10000, "10 seconds"),
            (70000, "1 minute 10 seconds"),
            (200000, "3 minutes 20 seconds"),
            (15600000, "4 hours 20 minutes"),
            (4830000, "1 hour 20 minutes 30 seconds"),
            (3630000, "1 hour 30 seconds")
        ]
        
        testStringConversion(tests) { (time, expected) in
            XCTAssertEqual(time.verboseStringValue, expected)
        }
    }
    
    func testTimeToMinuteString() {
        let tests: [(time: Int32, expected: String)] = [
            (10000, "0"),
            (-70000, "1"),
            (70000, "1"),
            (400000, "6"),
            (3600000, "60"),
            (15600000, "260")
        ]
        
        testStringConversion(tests) { (time, expected) in
            XCTAssertEqual(time.minuteStringValue, expected)
        }
    }
    
    // MARK: ETC
    func testCompare() {
        guard let greater = VLCTime(int: 2000), let smaller = VLCTime(int: 1100) else {
            XCTFail("Could not initialize VLCTime with int")
            return
        }
        XCTAssertEqual(greater.compare(smaller), ComparisonResult.orderedDescending)
        XCTAssertEqual(smaller.compare(greater), ComparisonResult.orderedAscending)
        XCTAssertEqual(greater.compare(greater), ComparisonResult.orderedSame)
        XCTAssertEqual(greater.isEqual(smaller), false)
    }
    
    func testHash() {
        let time = VLCTime(int: 10)
        XCTAssertNotNil(time?.hash())
    }
    
    func testNumberValue() {
        let expected = NSNumber(value: 10)
        let time = VLCTime(number: expected)
        let output = time?.numberValue
        XCTAssertEqual(output, expected)
    }
}
