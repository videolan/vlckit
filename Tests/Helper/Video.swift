/*****************************************************************************
 * Video.swift
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

struct Video {
    let name: String
    let type: String
    let meta: [String:String]
    
    #if os(OSX)
        let bundle = Bundle(identifier: "org.videolan.VLCKitTests")!
    #elseif os(iOS)
    let bundle = Bundle(identifier: "org.videolan.MobileVLCKitTests") != nil ? Bundle(identifier: "org.videolan.MobileVLCKitTests")! : Bundle(identifier: "org.videolan.DynamicMobileVLCKitTests")!
    #elseif os(tvOS)
        let bundle = Bundle(identifier: "org.videolan.TVVLCKitTests")!
    #endif
    
    static let standards = [Video.test1, Video.test2, Video.test3, Video.test4]
    
    static let test1 = Video(
        name: "bird",
        type: "m4v",
        meta: ["title": "bird.m4v", "date": "2017", "trackNumber": "1", "genre": "Chill", "description": "Bird looking into the abiss"]
    )
    static let test2 = Video(
        name: "bunny",
        type: "avi",
        meta: ["title": "bunny.avi", "genre": "Nature", "description": "Cute bunny looking for something"]
    )
    static let test3 = Video(
        name: "salmon",
        type: "mp4",
        meta: ["title": "salmon.mp4", "date": "2016", "trackNumber": "2", "genre": "Lake", "description": "Salmon trying to swim upstream"]
    )
    static let test4 = Video(
        name: "sea_lions",
        type: "mov",
        meta: ["title": "sea_lions.mov", "description": "Tanning sea lions", "genre": "Nature"]
    )
    static let invalid = Video(
        name: "invalid",
        type: "foo",
        meta: [:]
    )
    
    var media: VLCMedia {
        return VLCMedia(path: path)
    }
    
    var path: String {
        if type == "foo" {
            return title
        }
        let path = bundle.path(forResource: name, ofType: type)
        return path!
    }
    
    var url: URL {
        let url = bundle.url(forResource: name, withExtension: type)
        XCTAssertNotNil(url)
        return url!
    }
    
    var title: String {
        return "\(name).\(type)"
    }
}
