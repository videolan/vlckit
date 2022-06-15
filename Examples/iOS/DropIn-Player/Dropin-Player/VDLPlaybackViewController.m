/* Copyright (c) 2013, Felix Paul Kühne and VideoLAN
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

#import "VDLPlaybackViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface VDLPlaybackViewController () <UIGestureRecognizerDelegate, UIActionSheetDelegate, VLCMediaPlayerDelegate>
{
    VLCMediaPlayer *_mediaplayer;
    BOOL _setPosition;
    BOOL _displayRemainingTime;
    int _currentAspectRatioMask;
    NSArray *_aspectRatios;
    UIActionSheet *_audiotrackActionSheet;
    UIActionSheet *_subtitleActionSheet;
    NSURL *_url;
    NSTimer *_idleTimer;
}

@end

@implementation VDLPlaybackViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    /* fix-up UI */
    self.wantsFullScreenLayout = YES;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

    /* we want to influence the system volume */
    [[AVAudioSession sharedInstance] setDelegate:self];

    /* populate array of supported aspect ratios (there are more!) */
    _aspectRatios = @[@"DEFAULT", @"FILL_TO_SCREEN", @"4:3", @"16:9", @"16:10", @"2.21:1"];

    /* fix-up the UI */
    CGRect rect = self.toolbar.frame;
    rect.size.height += 20.;
    self.toolbar.frame = rect;
    [self.timeDisplay setTitle:@"" forState:UIControlStateNormal];

    /* this looks a bit weird, but let's try to support iOS 5 */
    UISlider *volumeSlider = nil;
    for (id aView in self.volumeView.subviews){
        if ([[[aView class] description] isEqualToString:@"MPVolumeSlider"]){
            volumeSlider = (UISlider *)aView;
            break;
        }
    }
    [volumeSlider addTarget:self
                     action:@selector(volumeSliderAction:)
           forControlEvents:UIControlEventValueChanged];

    /* setup gesture recognizer to toggle controls' visibility */
    _movieView.userInteractionEnabled = NO;
    UITapGestureRecognizer *tapOnVideoRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControlsVisible)];
    tapOnVideoRecognizer.delegate = self;
    [self.view addGestureRecognizer:tapOnVideoRecognizer];
}

- (void)playMediaFromURL:(NSURL*)theURL
{
    _url = theURL;
}

- (IBAction)playandPause:(id)sender
{
    if (_mediaplayer.isPlaying)
        [_mediaplayer pause];

    [_mediaplayer play];
}

- (IBAction)closePlayback:(id)sender
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:YES animated:YES];

    /* setup the media player instance, give it a delegate and something to draw into */
    _mediaplayer = [[VLCMediaPlayer alloc] init];
    _mediaplayer.delegate = self;
    _mediaplayer.drawable = self.movieView;

    /* enable debug logging from libvlc here */
    VLCConsoleLogger *consoleLogger = [[VLCConsoleLogger alloc] init];
    consoleLogger.level = kVLCLogLevelDebug;
    [_mediaplayer.libraryInstance setLoggers:@[consoleLogger]];

    /* listen for notifications from the player */
    [_mediaplayer addObserver:self forKeyPath:@"time" options:0 context:nil];
    [_mediaplayer addObserver:self forKeyPath:@"remainingTime" options:0 context:nil];

    /* create a media object and give it to the player */
    _mediaplayer.media = [VLCMedia mediaWithURL:_url];

    [_mediaplayer play];

    if (self.controllerPanel.hidden)
        [self toggleControlsVisible];

    [self _resetIdleTimer];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (_mediaplayer) {
        @try {
            [_mediaplayer removeObserver:self forKeyPath:@"time"];
            [_mediaplayer removeObserver:self forKeyPath:@"remainingTime"];
        }
        @catch (NSException *exception) {
            NSLog(@"we weren't an observer yet");
        }

        if (_mediaplayer.media)
            [_mediaplayer stop];

        if (_mediaplayer)
            _mediaplayer = nil;
    }

    if (_idleTimer) {
        [_idleTimer invalidate];
        _idleTimer = nil;
    }

    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
}

- (UIResponder *)nextResponder
{
    [self _resetIdleTimer];
    return [super nextResponder];
}

- (IBAction)positionSliderAction:(UISlider *)sender
{
    [self _resetIdleTimer];

    /* we need to limit the number of events sent by the slider, since otherwise, the user
     * wouldn't see the I-frames when seeking on current mobile devices. This isn't a problem
     * within the Simulator, but especially on older ARMv7 devices, it's clearly noticeable. */
    [self performSelector:@selector(_setPositionForReal) withObject:nil afterDelay:0.3];
    _setPosition = NO;
}

- (void)_setPositionForReal
{
    if (!_setPosition) {
        _mediaplayer.position = _positionSlider.value;
        _setPosition = YES;
    }
}

- (IBAction)positionSliderDrag:(id)sender
{
    [self _resetIdleTimer];
}

- (IBAction)volumeSliderAction:(id)sender
{
    [self _resetIdleTimer];
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{
    VLCMediaPlayerState currentState = _mediaplayer.state;

    if (currentState == VLCMediaPlayerStateBuffering) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [_mediaplayer performSelector:@selector(setTextRendererFont:) withObject:[defaults objectForKey:kVLCSettingSubtitlesFont]];
        [_mediaplayer performSelector:@selector(setTextRendererFontSize:) withObject:[defaults objectForKey:kVLCSettingSubtitlesFontSize]];
        [_mediaplayer performSelector:@selector(setTextRendererFontColor:) withObject:[defaults objectForKey:kVLCSettingSubtitlesFontColor]];
        [_mediaplayer performSelector:@selector(setTextRendererFontForceBold:) withObject:[defaults objectForKey:kVLCSettingSubtitlesBoldFont]];
    }

    /* distruct view controller on error */
    if (currentState == VLCMediaPlayerStateError)
        [self performSelector:@selector(closePlayback:) withObject:nil afterDelay:2.];

    /* or if playback ended */
    if (currentState == VLCMediaPlayerStateStopping || currentState == VLCMediaPlayerStateStopped)
        [self performSelector:@selector(closePlayback:) withObject:nil afterDelay:2.];

    [self.playPauseButton setTitle:[_mediaplayer isPlaying]? @"Pause" : @"Play" forState:UIControlStateNormal];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    self.positionSlider.value = [_mediaplayer position];

    if (_displayRemainingTime)
        [self.timeDisplay setTitle:[[_mediaplayer remainingTime] stringValue] forState:UIControlStateNormal];
    else
        [self.timeDisplay setTitle:[[_mediaplayer time] stringValue] forState:UIControlStateNormal];
}

- (IBAction)toggleTimeDisplay:(id)sender
{
    [self _resetIdleTimer];
    _displayRemainingTime = !_displayRemainingTime;
}

- (void)toggleControlsVisible
{
    BOOL controlsHidden = !self.controllerPanel.hidden;
    self.controllerPanel.hidden = controlsHidden;
    self.toolbar.hidden = controlsHidden;
    [[UIApplication sharedApplication] setStatusBarHidden:controlsHidden withAnimation:UIStatusBarAnimationFade];
}

- (void)_resetIdleTimer
{
    if (!_idleTimer)
        _idleTimer = [NSTimer scheduledTimerWithTimeInterval:5.
                                                      target:self
                                                    selector:@selector(idleTimerExceeded)
                                                    userInfo:nil
                                                     repeats:NO];
    else {
        if (fabs([_idleTimer.fireDate timeIntervalSinceNow]) < 5.)
            [_idleTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:5.]];
    }
}

- (void)idleTimerExceeded
{
    _idleTimer = nil;

    if (!self.controllerPanel.hidden)
        [self toggleControlsVisible];
}

- (IBAction)switchVideoDimensions:(id)sender
{
    [self _resetIdleTimer];

    NSUInteger count = [_aspectRatios count];

    if (_currentAspectRatioMask + 1 > count - 1) {
        _mediaplayer.videoAspectRatio = NULL;
        [_mediaplayer setCropRatioWithNumerator:1 denominator:0];
        _currentAspectRatioMask = 0;
        NSLog(@"crop disabled");
    } else {
        _currentAspectRatioMask++;

        if ([_aspectRatios[_currentAspectRatioMask] isEqualToString:@"FILL_TO_SCREEN"]) {
            UIScreen *screen = [UIScreen mainScreen];
            float f_ar = screen.bounds.size.width / screen.bounds.size.height;

            if (f_ar == (float)(640./1136.)) { // iPhone 5 aka 16:9.01
                [_mediaplayer setCropRatioWithNumerator:16 denominator:9];
            } else if (f_ar == (float)(2./3.)) { // all other iPhones
                [_mediaplayer setCropRatioWithNumerator:2 denominator:3];
            } else if (f_ar == .75) { // all iPads
                [_mediaplayer setCropRatioWithNumerator:4 denominator:3];
            } else if (f_ar == .5625) { // AirPlay
                [_mediaplayer setCropRatioWithNumerator:4 denominator:3];
            } else {
                NSLog(@"unknown screen format %f, trying a best effort crop", f_ar);
                [_mediaplayer setCropRatioWithNumerator:screen.bounds.size.width denominator:screen.bounds.size.height];
            }

            NSLog(@"FILL_TO_SCREEN");
            return;
        }

        [_mediaplayer setCropRatioWithNumerator:1 denominator:0];
        _mediaplayer.videoAspectRatio = (char *)[_aspectRatios[_currentAspectRatioMask] UTF8String];
        NSLog(@"crop switched to %@", _aspectRatios[_currentAspectRatioMask]);
    }
}

- (IBAction)switchAudioTrack:(id)sender
{
    _audiotrackActionSheet = [[UIActionSheet alloc] initWithTitle:@"audio track selector" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles: nil];
    NSArray *audioTracks = [_mediaplayer audioTrackNames];
    NSArray *audioTrackIndexes = [_mediaplayer audioTrackIndexes];

    NSUInteger count = [audioTracks count];
    for (NSUInteger i = 0; i < count; i++) {
        NSString *indexIndicator = ([audioTrackIndexes[i] intValue] == [_mediaplayer currentAudioTrackIndex])? @"\u2713": @"";
        NSString *buttonTitle = [NSString stringWithFormat:@"%@ %@", indexIndicator, audioTracks[i]];
        [_audiotrackActionSheet addButtonWithTitle:buttonTitle];
    }

    [_audiotrackActionSheet addButtonWithTitle:@"Cancel"];
    [_audiotrackActionSheet setCancelButtonIndex:[_audiotrackActionSheet numberOfButtons] - 1];
    [_audiotrackActionSheet showInView:self.audioSwitcherButton];
}

- (IBAction)switchSubtitleTrack:(id)sender
{
    NSArray *spuTracks = [_mediaplayer videoSubTitlesNames];
    NSArray *spuTrackIndexes = [_mediaplayer videoSubTitlesIndexes];

    NSUInteger count = [spuTracks count];
    if (count <= 1)
        return;
    _subtitleActionSheet = [[UIActionSheet alloc] initWithTitle:@"subtitle track selector" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles: nil];

    for (NSUInteger i = 0; i < count; i++) {
        NSString *indexIndicator = ([spuTrackIndexes[i] intValue] == [_mediaplayer currentVideoSubTitleIndex])? @"\u2713": @"";
        NSString *buttonTitle = [NSString stringWithFormat:@"%@ %@", indexIndicator, spuTracks[i]];
        [_subtitleActionSheet addButtonWithTitle:buttonTitle];
    }

    [_subtitleActionSheet addButtonWithTitle:@"Cancel"];
    [_subtitleActionSheet setCancelButtonIndex:[_subtitleActionSheet numberOfButtons] - 1];
    [_subtitleActionSheet showInView: self.subtitleSwitcherButton];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == [actionSheet cancelButtonIndex])
        return;

    NSArray *indexArray;
    if (actionSheet == _subtitleActionSheet) {
        indexArray = _mediaplayer.videoSubTitlesIndexes;
        if (buttonIndex <= indexArray.count) {
            _mediaplayer.currentVideoSubTitleIndex = [indexArray[buttonIndex] intValue];
        }
    } else if (actionSheet == _audiotrackActionSheet) {
        indexArray = _mediaplayer.audioTrackIndexes;
        if (buttonIndex <= indexArray.count) {
            _mediaplayer.currentAudioTrackIndex = [indexArray[buttonIndex] intValue];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
