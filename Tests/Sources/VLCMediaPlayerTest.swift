/*****************************************************************************
 * VLCMediaPlayerTest.swift
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *****************************************************************************/

import XCTest

private final class PlaylistPlayerDelegate: NSObject, VLCMediaPlayerDelegate, VLCMediaDelegate {
    var onSubitems: ((VLCMedia) -> Void)?
    var onMediaSubitems: ((VLCMedia) -> Void)?
    var onLength: ((Int64) -> Void)?

    func mediaPlayerSubitemsChanged(_ media: VLCMedia) {
        onSubitems?(media)
    }

    func mediaDidChangeSubitems(_ media: VLCMedia) {
        onMediaSubitems?(media)
    }

    func mediaPlayerLengthChanged(_ length: Int64) {
        onLength?(length)
    }
}

private final class QueuedPlayerEvents: NSObject, VLCEventsConfiguring {
    let queue = DispatchQueue(label: "org.videolan.VLCMediaPlayerTest.events")

    func dispatchQueue() -> DispatchQueue? { return queue }
    func isAsync() -> Bool { return true }
}

final class VLCMediaPlayerTest: XCTestCase {
    private var directory: URL!
    private var listPlayer: VLCMediaListPlayer!
    private var previousEventsConfiguration: VLCEventsConfiguring?

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousEventsConfiguration = VLCLibrary.sharedEventsConfiguration
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeWave(named: "first.wav")
        try writeWave(named: "second.wav")
        try "#EXTM3U\n#EXTINF:99,First\nfirst.wav\n#EXTINF:88,Second\nsecond.wav\n"
            .write(to: directory.appendingPathComponent("playlist.m3u"), atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        if let player = listPlayer {
            player.stop()
            let stopped = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                return player.state == .stopped
            }, object: nil)
            wait(for: [stopped], timeout: STANDARD_TIME_OUT)
        }
        listPlayer = nil
        VLCLibrary.sharedEventsConfiguration = previousEventsConfiguration
        try FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testPlaylistSubitemsReachPlayerDelegate() throws {
        try checkPlaylistSubitems(configuration: VLCEventsDefaultConfiguration(), autoAdvance: false)
    }

    func testPlaylistSubitemsReachPlayerDelegateOnLegacyQueue() throws {
        try checkPlaylistSubitems(configuration: VLCEventsLegacyConfiguration(), autoAdvance: false)
    }

    func testAutomaticAdvanceToPlaylistReachesPlayerDelegate() throws {
        try checkPlaylistSubitems(configuration: VLCEventsDefaultConfiguration(), autoAdvance: true)
    }

    func testPlaylistPreservesMediaDelegateAndNotification() throws {
        VLCLibrary.sharedEventsConfiguration = VLCEventsLegacyConfiguration()
        let playlist = try makePlaylist()
        let delegate = PlaylistPlayerDelegate()
        playlist.delegate = delegate
        var receivedMediaCallback = false
        var receivedNotification = false
        delegate.onMediaSubitems = { media in
            XCTAssertEqual(media, playlist)
            XCTAssertEqual(media.subitems?.count, 2)
            receivedMediaCallback = true
        }
        let observer = NotificationCenter.default.addObserver(forName: VLCMedia.subitemsChangedNotification,
                                                               object: playlist, queue: nil) { _ in
            receivedNotification = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let received = expectation(description: "Player delegate follows existing media events")
        delegate.onSubitems = { [weak delegate] media in
            delegate?.onSubitems = nil
            XCTAssertEqual(media, playlist)
            XCTAssertTrue(receivedMediaCallback)
            XCTAssertTrue(receivedNotification)
            received.fulfill()
        }
        start([playlist], delegate: delegate)
        wait(for: [received], timeout: STANDARD_TIME_OUT)
        withExtendedLifetime(delegate) {}
    }

    func testPlaybackReplacesPlaylistDurationBeforeNotifyingDelegate() throws {
        // Observe playlist hints synchronously before native playback advances.
        VLCLibrary.sharedEventsConfiguration = VLCEventsDefaultConfiguration()
        let playlist = try makePlaylist()
        let delegate = PlaylistPlayerDelegate()
        let parsed = expectation(description: "Playlist advertises durations before child playback")
        let updated = expectation(description: "Runtime duration replaces the playlist hint")
        delegate.onSubitems = { [weak delegate] media in
            delegate?.onSubitems = nil
            XCTAssertEqual(media.subitems?.media(at: 0)?.length.value, 99_000)
            XCTAssertEqual(media.subitems?.media(at: 1)?.length.value, 88_000)
            parsed.fulfill()
        }
        delegate.onLength = { [weak self, weak delegate] length in
            XCTAssertNotEqual(length, 0, "Normal startup must not synthesize a zero length")
            guard length > 0, let media = self?.listPlayer.mediaPlayer.media,
                  media.url?.lastPathComponent == "first.wav" else { return }
            delegate?.onLength = nil
            XCTAssertEqual(length, 250)
            XCTAssertEqual(media.length.value?.int64Value, length)
            updated.fulfill()
        }
        start([playlist], delegate: delegate)
        wait(for: [parsed, updated], timeout: STANDARD_TIME_OUT)
        withExtendedLifetime(delegate) {}
    }

    func testUnknownDurationRemainsUnknownWithoutSyntheticLengthEvent() throws {
        VLCLibrary.sharedEventsConfiguration = VLCEventsLegacyConfiguration()
        let stream = InputStream(data: Data(repeating: 0, count: 32_000))
        let media = try XCTAssertNotNilAndUnwrap(VLCMedia(stream: stream))
        media.addOptions(["demux": "rawaud", "rawaud-samplerate": "8000", "rawaud-channels": "1"])
        XCTAssertNil(media.length.value)
        let delegate = PlaylistPlayerDelegate()
        let syntheticZero = expectation(description: "Playing must not synthesize a zero length")
        syntheticZero.isInverted = true
        delegate.onLength = { length in
            if length == 0 { syntheticZero.fulfill() }
        }
        start([media], delegate: delegate)
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate { [weak self] _, _ in
            self?.listPlayer.mediaPlayer.isPlaying == true
        }, object: nil)
        wait(for: [playing], timeout: STANDARD_TIME_OUT)
        wait(for: [syntheticZero], timeout: 1.0)
        // libvlc may expose zero once parsed; both zero and null mean unknown.
        XCTAssertLessThanOrEqual(media.length.value?.int64Value ?? -1, 0)
        withExtendedLifetime(delegate) {}
    }

    func testDurationReadsDoNotDependOnDeferredPlayerEvents() throws {
        let configuration = QueuedPlayerEvents()
        VLCLibrary.sharedEventsConfiguration = configuration
        try writeWave(named: "long.wav", sampleCount: 80_000)
        let first = try XCTAssertNotNilAndUnwrap(VLCMedia(url: directory.appendingPathComponent("long.wav")))
        let second = try XCTAssertNotNilAndUnwrap(VLCMedia(url: directory.appendingPathComponent("second.wav")))
        XCTAssertNil(first.length.value)
        XCTAssertNil(second.length.value)
        let delegate = PlaylistPlayerDelegate()
        configuration.queue.suspend()
        defer { configuration.queue.resume() }
        start([first, second], delegate: delegate)
        let firstDuration = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            first.length.value == 10_000
        }, object: nil)
        wait(for: [firstDuration], timeout: STANDARD_TIME_OUT)
        listPlayer.playItem(at: 1)
        let secondDuration = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            second.length.value == 250
        }, object: nil)
        wait(for: [secondDuration], timeout: STANDARD_TIME_OUT)
        XCTAssertEqual(first.length.value, 10_000)
        XCTAssertEqual(second.length.value, 250)
        withExtendedLifetime(delegate) {}
    }

    private func checkPlaylistSubitems(configuration: VLCEventsConfiguring, autoAdvance: Bool) throws {
        VLCLibrary.sharedEventsConfiguration = configuration
        let playlist = try makePlaylist()
        let delegate = PlaylistPlayerDelegate()
        let received = expectation(description: "Playlist reaches the player without a media delegate")
        delegate.onSubitems = { [weak delegate] media in
            delegate?.onSubitems = nil
            XCTAssertEqual(media, playlist)
            XCTAssertNil(media.delegate)
            XCTAssertEqual(media.subitems?.count, 2)
            XCTAssertEqual(media.subitems?.media(at: 0)?.url?.lastPathComponent, "first.wav")
            XCTAssertEqual(media.subitems?.media(at: 1)?.url?.lastPathComponent, "second.wav")
            if configuration is VLCEventsLegacyConfiguration {
                XCTAssertTrue(Thread.isMainThread)
            }
            received.fulfill()
        }
        var queue = [playlist]
        if autoAdvance {
            let first = try XCTAssertNotNilAndUnwrap(VLCMedia(url: directory.appendingPathComponent("first.wav")))
            queue.insert(first, at: 0)
        }
        start(queue, delegate: delegate)
        wait(for: [received], timeout: STANDARD_TIME_OUT)
        withExtendedLifetime(delegate) {}
    }

    private func makePlaylist() throws -> VLCMedia {
        return try XCTAssertNotNilAndUnwrap(VLCMedia(url: directory.appendingPathComponent("playlist.m3u")))
    }

    private func start(_ queue: [VLCMedia], delegate: PlaylistPlayerDelegate) {
        listPlayer = VLCMediaListPlayer(options: ["--no-video", "--aout=dummy"])
        listPlayer.mediaPlayer.delegate = delegate
        listPlayer.mediaList = VLCMediaList(array: queue)
        listPlayer.play()
    }

    private func writeWave(named name: String, sampleCount: UInt32 = 2000) throws {
        // A quarter-second of mono PCM needs no downloaded fixtures or optional codecs.
        let sampleRate: UInt32 = 8000
        let byteCount = sampleCount * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + byteCount))
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(sampleRate)
        append(sampleRate * 2)
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: "data".utf8)
        append(byteCount)
        data.append(Data(repeating: 0, count: Int(byteCount)))
        try data.write(to: directory.appendingPathComponent(name))
    }
}
