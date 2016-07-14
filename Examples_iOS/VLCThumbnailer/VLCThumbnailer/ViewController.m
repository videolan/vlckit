//
//  ViewController.m
//  VLCThumbnailer
//
//  Created by Felix Paul Kühne on 14/07/16.
//  Copyright © 2016 VideoLAN. All rights reserved.
//

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
    sharedLibrary.debugLogging = YES;
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
