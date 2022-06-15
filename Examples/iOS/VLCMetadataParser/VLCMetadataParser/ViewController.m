/* Copyright (c) 2016, 2022 Felix Paul Kühne, VideoLabs SAS and VideoLAN
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
    _textView.backgroundColor = [UIColor clearColor];
    _textView.textColor = [UIColor whiteColor];
    _textView.editable = NO;
    [self.view addSubview:_textView];

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
    _media = [VLCMedia mediaWithURL:[NSURL URLWithString:@"http://streams.videolan.org/streams/mp4/Mr_MrsSmith-h264_aac.mp4"]];
    _media.delegate = self;

    _timeOutTimer = [NSTimer scheduledTimerWithTimeInterval:3. target:self selector:@selector(parsingTimeout:) userInfo:nil repeats:NO];

    [_media parseWithOptions:VLCMediaParseLocal|VLCMediaFetchLocal|VLCMediaParseNetwork|VLCMediaFetchNetwork];

    [super viewDidAppear:animated];
}

- (void)parsingTimeout:(NSTimer *)timer
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSMutableString *parsingOutput = [[NSMutableString alloc] initWithFormat:@"\n\nParsing of the following media reached its timeout: %@\n", _media];
    _textView.text = parsingOutput;
}

- (void)mediaDidFinishParsing:(VLCMedia *)media
{
    [_timeOutTimer invalidate];

    NSMutableString *parsingOutput = [[NSMutableString alloc] initWithFormat:@"\n\nParsed: %@\nNumber of tracks: %lu\n", _media, (unsigned long)[[_media tracksInformation] count]];

    _media.delegate = nil;

    VLCMediaMetaData *metaData = _media.metaData;
    [metaData prefetch];

    NSArray *tracks = _media.tracksInformation;
    for (VLCMediaTracksInformation *trackInfo in tracks) {
        [parsingOutput appendString:@"\n"];
        VLCMediaTracksInformationType type = trackInfo.type;
        if (type == VLCMediaTracksInformationTypeVideo) {
            [parsingOutput appendFormat:@"Video Track:\nDimensions: %ux%u\n",
             trackInfo.video.width,
             trackInfo.video.height];
        } else if (type == VLCMediaTracksInformationTypeAudio) {
            [parsingOutput appendFormat:@"Audio Track:\nSample rate: %u\nNumber of Channels: %u\n",
             trackInfo.audio.rate,
             trackInfo.audio.channelsNumber];
        } else if (type == VLCMediaTracksInformationTypeText) {
            [parsingOutput appendFormat:@"SPU track:\nText Encoding: %@\n", trackInfo.text.encoding];
        }

        int fourcc = trackInfo.fourcc;
        [parsingOutput appendFormat:@"Bitrate: %i\nCodec: %@\nFourCC: %4.4s\nCodec Level: %i\nCodec Profile: %i\nLanguage: %@\n",
         trackInfo.bitrate,
         [VLCMedia codecNameForFourCC:trackInfo.fourcc trackType:trackInfo.type],
         (char *)&fourcc,
         trackInfo.level,
         trackInfo.profile,
         trackInfo.language];
    }
    [parsingOutput appendFormat:@"\nDuration: %@\n", [[_media length] stringValue]];

    [parsingOutput appendFormat:@"\nContent Info:\nTitle: %@\nArtist: %@\nAlbum Artist: %@\nAlbum name: %@\nGenre: %@\nTrack number: %u\nDisc number: %u\nArtwork URL: %@",
     metaData.title, metaData.artist, metaData.albumArtist, metaData.album, metaData.genre, metaData.trackNumber, metaData.discNumber, metaData.artworkURL];

    NSString *artworkPath = [self artworkPathForMediaItemWithTitle:metaData.title
                                                            Artist:metaData.artist
                                                      andAlbumName:metaData.album];
    if (artworkPath) {
        [parsingOutput appendFormat:@"\nArtwork path: %@", artworkPath];
    }

    NSLog(@"%@", parsingOutput);

    [_activityIndicatorView stopAnimating];
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
