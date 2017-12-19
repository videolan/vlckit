//
//  ViewController.m
//  VLCMediaTests
//
//  Created by Felix Paul Kühne on 19.12.17.
//  Copyright © 2017 Felix Paul Kühne. All rights reserved.
//

#import "ViewController.h"
#import <MobileVLCKit/MobileVLCKit.h>

@interface ViewController () <VLCMediaListDelegate, VLCMediaDelegate>
{
    VLCMedia *_theMedia;
    VLCMediaList *_theMediaList;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    /* create a media object and give it to the player */
    NSString *urlString = @"file:///Users/fkuehne/Downloads/Alice.m4v";

    _theMedia = [VLCMedia mediaWithURL:[NSURL URLWithString:urlString]];
    NSLog(@"%s: media: %@", __PRETTY_FUNCTION__, _theMedia.description);

    _theMediaList = [[VLCMediaList alloc] init];
    _theMediaList.delegate = self;
    NSInteger ret = [_theMediaList addMedia:_theMedia];

    NSLog(@"%s: ret: %li", __func__, (long)ret);

    NSLog(@"%s: list: %@", __func__, _theMediaList);

    NSLog(@"%s: media in list: %@", __func__, [_theMediaList mediaAtIndex:0]);

    [[_theMediaList mediaAtIndex:0] parseWithOptions:VLCMediaParseLocal];
}

- (void)mediaList:(VLCMediaList *)aMediaList mediaAdded:(VLCMedia *)media atIndex:(NSInteger)index
{
    NSLog(@"%s: list: %@", __func__, aMediaList);
    NSLog(@"%s: media: %@", __func__, media);
}

- (void)mediaDidFinishParsing:(VLCMedia *)aMedia
{
    NSLog(@"%s: media: %@", __PRETTY_FUNCTION__, aMedia.description);
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

@end
