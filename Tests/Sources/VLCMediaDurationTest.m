/*****************************************************************************
 * VLCMediaDurationTest.m
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *****************************************************************************/

#import <XCTest/XCTest.h>
#import <VLCKit/VLCKit.h>

// Keep private native bridging declarations confined to this integration test.
@interface VLCMedia (DurationTests)
+ (instancetype)mediaWithLibVLCMediaDescriptor:(void *)descriptor;
- (void *)libVLCMediaDescriptor;
@end

@interface VLCMediaDurationTest : XCTestCase <VLCMediaPlayerDelegate>
@property (nonatomic, copy) void (^onSubitems)(VLCMedia *);
@end

@implementation VLCMediaDurationTest
- (void)mediaPlayerSubitemsChanged:(VLCMedia *)media
{
    if (self.onSubitems)
        self.onSubitems(media);
}

- (void)testDistinctWrappersReadTheSameNativeDuration
{
    NSURL *directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil]);
    NSURL *url = [directory URLByAppendingPathComponent:@"tone.wav"];
    // One second of 8 kHz mono, 16-bit PCM, with a little-endian WAV header.
    const unsigned char header[] = {
        'R','I','F','F', 0xa4,0x3e,0,0, 'W','A','V','E',
        'f','m','t',' ', 16,0,0,0, 1,0,1,0, 0x40,0x1f,0,0,
        0x80,0x3e,0,0, 2,0,16,0, 'd','a','t','a', 0x80,0x3e,0,0
    };
    NSMutableData *wave = [NSMutableData dataWithBytes:header length:sizeof(header)];
    [wave increaseLengthBy:16000];
    XCTAssertTrue([wave writeToURL:url atomically:YES]);

    NSURL *playlistURL = [directory URLByAppendingPathComponent:@"playlist.m3u"];
    XCTAssertTrue([@"#EXTM3U\n#EXTINF:99,Hint\ntone.wav\n" writeToURL:playlistURL atomically:YES encoding:NSUTF8StringEncoding error:nil]);
    __block VLCMedia *media;
    __block VLCMedia *wrapper;
    VLCMedia *sameURL = [VLCMedia mediaWithURL:url];
    XCTestExpectation *discovered = [self expectationWithDescription:@"Read hint through both wrappers before playback"];
    self.onSubitems = ^(VLCMedia *playlist) {
        if (media)
            return;
        media = [playlist.subitems mediaAtIndex:0];
        wrapper = [VLCMedia mediaWithLibVLCMediaDescriptor:media.libVLCMediaDescriptor];
        XCTAssertNotEqual(media, wrapper);
        XCTAssertEqualObjects(media, wrapper);
        XCTAssertNotEqualObjects(media, sameURL);
        XCTAssertEqualObjects(media.length.value, @99000);
        XCTAssertEqualObjects(wrapper.length.value, @99000);
        XCTAssertNil(sameURL.length.value);
        [discovered fulfill];
    };
    id<VLCEventsConfiguring> previousConfiguration = VLCLibrary.sharedEventsConfiguration;
    VLCLibrary.sharedEventsConfiguration = [VLCEventsDefaultConfiguration new];
    VLCMediaListPlayer *player = [[VLCMediaListPlayer alloc] initWithOptions:@[@"--no-video", @"--aout=dummy"]];
    player.mediaPlayer.delegate = self;
    player.mediaList = [[VLCMediaList alloc] initWithArray:@[[VLCMedia mediaWithURL:playlistURL]]];
    [player play];
    [self waitForExpectations:@[discovered] timeout:5];
    NSPredicate *duration = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return media.length.value.longLongValue == 1000;
    }];
    [self waitForExpectations:@[[[XCTNSPredicateExpectation alloc] initWithPredicate:duration object:nil]] timeout:5];
    XCTAssertEqualObjects(wrapper.length.value, @1000);
    XCTAssertNil(sameURL.length.value);
    [player stop];
    NSPredicate *stopped = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return player.state == VLCMediaPlayerStateStopped;
    }];
    [self waitForExpectations:@[[[XCTNSPredicateExpectation alloc] initWithPredicate:stopped object:nil]] timeout:5];
    XCTAssertEqualObjects(media.length.value, @1000);
    XCTAssertEqualObjects(wrapper.length.value, @1000);
    self.onSubitems = nil;
    VLCLibrary.sharedEventsConfiguration = previousConfiguration;
    XCTAssertTrue([NSFileManager.defaultManager removeItemAtURL:directory error:nil]);
}
@end
