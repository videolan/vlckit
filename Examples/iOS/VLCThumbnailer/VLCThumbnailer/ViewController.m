/* Copyright (c) 2016, Felix Paul Kühne, VideoLabs SAS and VideoLAN
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

@interface ViewController () <VLCMediaPlayerDelegate, VLCMediaThumbnailerDelegate, VLCMediaDelegate>
{
    UIImageView *_imageView;
    UIActivityIndicatorView *_activityIndicatorView;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor darkGrayColor];

    _imageView = [[UIImageView alloc] initWithFrame:self.view.frame];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.clipsToBounds = YES;
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_imageView];

    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicatorView.center = self.view.center;
    [self.view addSubview:_activityIndicatorView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [_activityIndicatorView startAnimating];
    VLCLibrary *sharedLibrary = [VLCLibrary sharedLibrary];
    VLCConsoleLogger *consoleLogger = [[VLCConsoleLogger alloc] init];
    consoleLogger.level = kVLCLogLevelDebug;
    [sharedLibrary setLoggers:@[consoleLogger]];
    VLCMedia *media = [VLCMedia mediaWithURL:[NSURL URLWithString:@"http://streams.videolan.org/streams/mp4/Mr_MrsSmith-h264_aac.mp4"]];
    media.delegate = self;
    VLCMediaThumbnailer *thumbnailer = [VLCMediaThumbnailer thumbnailerWithMedia:media delegate:self andVLCLibrary:[VLCLibrary sharedLibrary]];
    [thumbnailer fetchThumbnail];
    [super viewDidAppear:animated];
}

- (void)mediaThumbnailerDidTimeOut:(VLCMediaThumbnailer *)mediaThumbnailer
{
    [_activityIndicatorView stopAnimating];
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, mediaThumbnailer);
}

- (void)mediaThumbnailer:(VLCMediaThumbnailer *)mediaThumbnailer didFinishThumbnail:(CGImageRef)thumbnail
{
    [_activityIndicatorView stopAnimating];
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, mediaThumbnailer);
    _imageView.image = [UIImage imageWithCGImage:thumbnail];
}

@end
