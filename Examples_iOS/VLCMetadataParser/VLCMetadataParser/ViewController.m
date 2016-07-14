//
//  ViewController.m
//  VLCThumbnailer
//
//  Created by Felix Paul Kühne on 14/07/16.
//  Copyright © 2016 VideoLAN. All rights reserved.
//

#import "ViewController.h"
#import <MobileVLCKit/MobileVLCKit.h>
#import <CommonCrypto/CommonDigest.h> // for MD5

@interface ViewController () <VLCMediaPlayerDelegate, VLCMediaDelegate>
{
    UITextView *_textView;
    UIActivityIndicatorView *_activityIndicatorView;
    NSTimer *_timeOutTimer;
    VLCMedia *_media;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor darkGrayColor];

    _textView = [[UITextView alloc] initWithFrame:self.view.frame];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_textView];

    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicatorView.center = self.view.center;
    [self.view addSubview:_activityIndicatorView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [_activityIndicatorView startAnimating];
    VLCLibrary *sharedLibrary = [VLCLibrary sharedLibrary];
    sharedLibrary.debugLogging = YES;
    _media = [VLCMedia mediaWithURL:[NSURL URLWithString:@"http://streams.videolan.org/streams/mp4/Mr_MrsSmith-h264_aac.mp4"]];
    _media.delegate = self;

    _timeOutTimer = [NSTimer scheduledTimerWithTimeInterval:3. target:self selector:@selector(parsingTimeout:) userInfo:nil repeats:NO];

    [_media parseWithOptions:VLCMediaParseLocal|VLCMediaFetchLocal|VLCMediaParseNetwork|VLCMediaFetchNetwork];

    [super viewDidAppear:animated];
}

- (void)parsingTimeout:(NSTimer *)timer
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)mediaDidFinishParsing:(VLCMedia *)media
{
    [_timeOutTimer invalidate];

    NSLog(@"Parsed %@ - %lu tracks", _media, (unsigned long)[[_media tracksInformation] count]);

    NSMutableString *parsingOutput = [[NSMutableString alloc] initWithString:@"\n\n"];

    _media.delegate = nil;
    NSArray *tracks = [_media tracksInformation];
    BOOL mediaHasVideo = NO;
    for (NSDictionary *track in tracks) {
        [parsingOutput appendString:@"\n"];
        NSString *type = track[VLCMediaTracksInformationType];
        if ([type isEqualToString:VLCMediaTracksInformationTypeVideo]) {
            [parsingOutput appendFormat:@"Video Track:\nDimensions: %@x%@\n",
             track[VLCMediaTracksInformationVideoWidth],
             track[VLCMediaTracksInformationVideoHeight]];
            mediaHasVideo = YES;
        } else if ([type isEqualToString:VLCMediaTracksInformationTypeAudio]) {
            [parsingOutput appendFormat:@"Audio Track:\nSample rate: %@\nNumber of Channels: %@\n",
             track[VLCMediaTracksInformationAudioRate],
             track[VLCMediaTracksInformationAudioChannelsNumber]];
        } else if ([type isEqualToString:VLCMediaTracksInformationTypeText]) {
            [parsingOutput appendFormat:@"SPU track:\nText Encoding: %@\n", track[VLCMediaTracksInformationTextEncoding]];
        }

        int fourcc = [track[VLCMediaTracksInformationCodec] intValue];
        [parsingOutput appendFormat:@"Bitrate: %@\nCodec: %@\nFourCC: %4.4s\nCodec Level: %@\nCodec Profile: %@\nLanguage: %@\n",
         track[VLCMediaTracksInformationBitrate],
         [VLCMedia codecNameForFourCC:[track[VLCMediaTracksInformationCodec] intValue] trackType:nil],
         (char *)&fourcc,
         track[VLCMediaTracksInformationCodecLevel],
         track[VLCMediaTracksInformationCodecProfile],
         track[VLCMediaTracksInformationLanguage]];
    }
    [parsingOutput appendFormat:@"\nDuration: %@\n", [[_media length] numberValue]];

    if (!mediaHasVideo) {
        NSDictionary *audioContentInfo = [_media metaDictionary];
        if (audioContentInfo && audioContentInfo.count > 0) {
            [parsingOutput appendFormat:@"\nContent Info:\nTitle: %@\nArtist: %@\nAlbum name: %@\nRelease Year: %@\nGenre: %@\nTrack number: %@\nDisc number: %@",
             audioContentInfo[VLCMetaInformationTitle],
             audioContentInfo[VLCMetaInformationArtist],
             audioContentInfo[VLCMetaInformationAlbum],
             audioContentInfo[VLCMetaInformationDate],
             audioContentInfo[VLCMetaInformationGenre],
             audioContentInfo[VLCMetaInformationTrackNumber],
             audioContentInfo[VLCMetaInformationDiscNumber]];

            NSString *artworkPath = [self artworkPathForMediaItemWithTitle:audioContentInfo[VLCMetaInformationTitle]
                                                                    Artist:audioContentInfo[VLCMetaInformationArtist]
                                                              andAlbumName:audioContentInfo[VLCMetaInformationAlbum]];
            if (artworkPath) {
                [parsingOutput appendFormat:@"Artwork path: %@", artworkPath];
            }
        }
    }

    _textView.text = parsingOutput;
}

#pragma mark - audio file specific code

- (NSString *)artworkPathForMediaItemWithTitle:(NSString *)title Artist:(NSString*)artist andAlbumName:(NSString*)albumname
{
    NSString *artworkURL;
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = searchPaths[0];
    cacheDir = [cacheDir stringByAppendingFormat:@"/%@", [[NSBundle mainBundle] bundleIdentifier]];

    if ((artist.length == 0 || albumname.length == 0) && title != nil && title.length > 0) {
        /* Use generated hash to find art */
        artworkURL = [cacheDir stringByAppendingFormat:@"/art/arturl/%@/art.jpg", [self _md5FromString:title]];
    } else {
        /* Otherwise, it was cached by artist and album */
        artworkURL = [cacheDir stringByAppendingFormat:@"/art/artistalbum/%@/%@/art.jpg", artist, albumname];
    }

    return artworkURL;
}

- (NSString *)_md5FromString:(NSString *)string
{
    const char *ptr = [string UTF8String];
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(ptr, (unsigned int)strlen(ptr), md5Buffer);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x",md5Buffer[i]];

    return [NSString stringWithString:output];
}

@end
