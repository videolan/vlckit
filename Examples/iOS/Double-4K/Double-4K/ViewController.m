/* Copyright (c) 2020, Felix Paul Kühne, VideoLabs SAS and VideoLAN
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice,
*    this list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice,
*    this list of conditions and the following disclaimer in the documentation
*    and/or other materials provided with the distribution.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
* ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
* LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
* CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
* SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
* INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
* CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
* POSSIBILITY OF SUCH DAMAGE. */

#import "ViewController.h"
#import <MobileVLCKit/MobileVLCKit.h>

@interface ViewController ()
{
    VLCMedia *_mediaOne;
    VLCMediaPlayer *_mediaPlayerOne;
    VLCMedia *_mediaTwo;
    VLCMediaPlayer *_mediaPlayerTwo;
    VLCMedia *_mediaThree;
    VLCMediaPlayer *_mediaPlayerThree;
    VLCMedia *_mediaFour;
    VLCMediaPlayer *_mediaPlayerFour;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // FIXME: set this to your own sample file
    NSURL *mediaURL = [[NSBundle mainBundle] URLForResource:@"IMG_1456" withExtension:@"MOV"];

    _mediaOne = [VLCMedia mediaWithURL:mediaURL];
    _mediaPlayerOne = [[VLCMediaPlayer alloc] init];
    _mediaPlayerOne.drawable = self.videoViewOne;
    _mediaPlayerOne.media = _mediaOne;

    _mediaTwo = [VLCMedia mediaWithURL:mediaURL];
    _mediaPlayerTwo = [[VLCMediaPlayer alloc] init];
    _mediaPlayerTwo.drawable = self.videoViewTwo;
    _mediaPlayerTwo.media = _mediaTwo;
    VLCConsoleLogger *consoleLogger = [[VLCConsoleLogger alloc] init];
    consoleLogger.level = kVLCLogLevelDebug;
    [_mediaPlayerTwo.libraryInstance setLoggers:@[consoleLogger]];

    _mediaThree = [VLCMedia mediaWithURL:mediaURL];
    _mediaPlayerThree = [[VLCMediaPlayer alloc] init];
    _mediaPlayerThree.drawable = self.videoViewThree;
    _mediaPlayerThree.media = _mediaTwo;

    _mediaFour = [VLCMedia mediaWithURL:mediaURL];
    _mediaPlayerFour = [[VLCMediaPlayer alloc] init];
    _mediaPlayerFour.drawable = self.videoViewFour;
    _mediaPlayerFour.media = _mediaFour;

    UITapGestureRecognizer *tapGestureOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playOne:)];
    [self.videoViewOne addGestureRecognizer:tapGestureOne];
    UITapGestureRecognizer *tapGestureTwo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playTwo:)];
    [self.videoViewTwo addGestureRecognizer:tapGestureTwo];
    UITapGestureRecognizer *tapGestureThree = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playThree:)];
    [self.videoViewThree addGestureRecognizer:tapGestureThree];
    UITapGestureRecognizer *tapGestureFour = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playFour:)];
    [self.videoViewFour addGestureRecognizer:tapGestureFour];
}

- (void)playOne:(UITapGestureRecognizer *)sender
{
    if (_mediaPlayerOne.isPlaying) {
        [_mediaPlayerOne stop];
    } else {
        [_mediaPlayerOne play];
    }
}

- (void)playTwo:(UITapGestureRecognizer *)sender
{
    if (_mediaPlayerTwo.isPlaying) {
        [_mediaPlayerTwo stop];
    } else {
        [_mediaPlayerTwo play];
    }
}

- (void)playThree:(UITapGestureRecognizer *)sender
{
    if (_mediaPlayerThree.isPlaying) {
        [_mediaPlayerThree stop];
    } else {
        [_mediaPlayerThree play];
    }
}

- (void)playFour:(UITapGestureRecognizer *)sender
{
    if (_mediaPlayerFour.isPlaying) {
        [_mediaPlayerFour stop];
    } else {
        [_mediaPlayerFour play];
    }
}

@end
