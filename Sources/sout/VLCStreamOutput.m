/*****************************************************************************
 * VLCStreamOutput.m: VLCKit.framework VLCStreamOutput implementation
 *****************************************************************************
 * Copyright (C) 2008 Pierre d'Herbemont
 * Copyright (C) 2008, 2014 VLC authors and VideoLAN
 * Copyright (C) 2012 Brendon Justin
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan.org>
 *          Brendon Justin <brendonjustin # gmail.com>
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

#import "VLCStreamOutput.h"
#import "VLCLibVLCBridging.h"

@interface VLCStreamOutput ()
{
    NSMutableDictionary *_options;
}
@end

@implementation VLCStreamOutput

- (instancetype)init
{
    return [self initWithOptionDictionary:nil];
}

- (instancetype)initWithOptionDictionary:(NSDictionary *)dictionary
{
    if (self = [super init])
        _options = [dictionary mutableCopy];

    return self;
}
- (NSString *)description
{
    return [self representedLibVLCOptions];
}
+ (instancetype)streamOutputWithOptionDictionary:(NSDictionary *)dictionary
{
    return [[self alloc] initWithOptionDictionary:dictionary];
}
+ (id)rtpBroadcastStreamOutputWithSAPAnnounce:(NSString *)announceName
{
    return [self streamOutputWithOptionDictionary:@{
        @"rtpOptions" : @{
            @"muxer" : @"ts",
            @"access" : @"file",
            @"sdp" : @"sdp",
            @"sap" : @"sap",
            @"name" : [announceName copy],
            @"destination" : @"239.255.1.1"
        }
    }];
}

+ (id)rtpBroadcastStreamOutput
{
    return [self rtpBroadcastStreamOutputWithSAPAnnounce:@"Helloworld!"];
}

+ (id)ipodStreamOutputWithFilePath:(NSString *)filePath
{
    return [self streamOutputWithOptionDictionary:@{
        @"transcodingOptions" : @{
            @"videoCodec" : @"h264",
            @"videoBitrate" : @"1024",
            @"audioCodec" : @"mp3",
            @"audioBitrate" : @"128",
            @"channels" : @"2",
            @"width" : @"640",
            @"height" : @"480",
            @"audio-sync" : @"Yes"
        },
        @"outputOptions" : @{
            @"muxer" : @"mp4",
            @"access" : @"file",
            @"destination" : [[NSURL URLWithString:filePath] absoluteString]
        }
    }];
}

+ (id)mpeg4StreamOutputWithFilePath:(NSString *)filePath
{
    return [self streamOutputWithOptionDictionary:@{
        @"transcodingOptions" : @{
            @"videoCodec" : @"mp4v",
            @"videoBitrate" : @"1024",
            @"audioCodec" : @"mp4a",
            @"audioBitrate" : @"192"
        },
        @"outputOptions" : @{
            @"muxer" : @"mp4",
            @"access" : @"file",
            @"destination" : [filePath copy]
        }
    }];
}

+ (instancetype)streamOutputWithFilePath:(NSString *)filePath
{
    return [self streamOutputWithOptionDictionary:@{
        @"outputOptions" : @{
            @"muxer" : @"ps",
            @"access" : @"file",
            @"destination" : [filePath copy]
        }
    }];
}

+ (id)mpeg2StreamOutputWithFilePath:(NSString *)filePath;
{
    return [self streamOutputWithOptionDictionary:@{
        @"transcodingOptions" : @{
            @"videoCodec" : @"mp2v",
            @"videoBitrate" : @"1024",
            @"audioCodec" : @"mpga",
            @"audioBitrate" : @"128",
            @"audio-sync" : @"Yes"
        },
        @"outputOptions" : @{
            @"muxer" : @"ps",
            @"access" : @"file",
            @"destination" : [filePath copy]
        }
    }];
}
@end

@implementation VLCStreamOutput (LibVLCBridge)
- (NSString *)representedLibVLCOptions
{
    NSString * representedOptions;
    NSMutableArray * subOptions = [NSMutableArray array];
    NSMutableArray * optionsAsArray = [NSMutableArray array];
    NSDictionary * transcodingOptions = _options[@"transcodingOptions"];
    if( transcodingOptions )
    {
        NSString * videoCodec = transcodingOptions[@"videoCodec"];
        NSString * audioCodec = transcodingOptions[@"audioCodec"];
        NSString * subtitleCodec = transcodingOptions[@"subtitleCodec"];
        NSString * videoBitrate = transcodingOptions[@"videoBitrate"];
        NSString * audioBitrate = transcodingOptions[@"audioBitrate"];
        NSString * channels = transcodingOptions[@"channels"];
        NSString * height = transcodingOptions[@"height"];
        NSString * canvasHeight = transcodingOptions[@"canvasHeight"];
        NSString * width = transcodingOptions[@"width"];
        NSString * audioSync = transcodingOptions[@"audioSync"];
        NSString * videoEncoder = transcodingOptions[@"videoEncoder"];
        NSString * subtitleEncoder = transcodingOptions[@"subtitleEncoder"];
        NSString * subtitleOverlay = transcodingOptions[@"subtitleOverlay"];
        if( videoEncoder )   [subOptions addObject:[NSString stringWithFormat:@"venc=%@", videoEncoder]];
        if( videoCodec )   [subOptions addObject:[NSString stringWithFormat:@"vcodec=%@", videoCodec]];
        if( videoBitrate ) [subOptions addObject:[NSString stringWithFormat:@"vb=%@", videoBitrate]];
        if( width ) [subOptions addObject:[NSString stringWithFormat:@"width=%@", width]];
        if( height ) [subOptions addObject:[NSString stringWithFormat:@"height=%@", height]];
        if( canvasHeight ) [subOptions addObject:[NSString stringWithFormat:@"canvas-height=%@", canvasHeight]];
        if( audioCodec )   [subOptions addObject:[NSString stringWithFormat:@"acodec=%@", audioCodec]];
        if( audioBitrate ) [subOptions addObject:[NSString stringWithFormat:@"ab=%@", audioBitrate]];
        if( channels ) [subOptions addObject:[NSString stringWithFormat:@"channels=%@", channels]];
        if( audioSync ) [subOptions addObject:@"audioSync"];
        if( subtitleCodec ) [subOptions addObject:[NSString stringWithFormat:@"scodec=%@", subtitleCodec]];
        if( subtitleEncoder ) [subOptions addObject:[NSString stringWithFormat:@"senc=%@", subtitleEncoder]];
        if( subtitleOverlay ) [subOptions addObject:@"soverlay"];
        [optionsAsArray addObject: [NSString stringWithFormat:@"#transcode{%@}", [subOptions componentsJoinedByString:@","]]];
        [subOptions removeAllObjects];
    }

    NSDictionary * outputOptions = _options[@"outputOptions"];
    if( outputOptions )
    {
        NSString * muxer = outputOptions[@"muxer"];
        NSString * destination = outputOptions[@"destination"];
        NSString * url = outputOptions[@"url"];
        NSString * access = outputOptions[@"access"];
        if( muxer )       [subOptions addObject:[NSString stringWithFormat:@"mux=%@", muxer]];
        if( destination ) [subOptions addObject:[NSString stringWithFormat:@"dst=\"%@\"", [destination stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]]];
        if( url ) [subOptions addObject:[NSString stringWithFormat:@"url=\"%@\"", [url stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]]];
        if( access )      [subOptions addObject:[NSString stringWithFormat:@"access=%@", access]];
        NSString *std = [NSString stringWithFormat:@"std{%@}", [subOptions componentsJoinedByString:@","]];
        if ( !transcodingOptions )
            std = [NSString stringWithFormat:@"#%@", std];

        [optionsAsArray addObject:std];
        [subOptions removeAllObjects];
    }

    NSDictionary * rtpOptions = _options[@"rtpOptions"];
    if( rtpOptions )
    {
        NSString * muxer = rtpOptions[@"muxer"];
        NSString * destination = rtpOptions[@"destination"];
        NSString * sdp = rtpOptions[@"sdp"];
        NSString * name = rtpOptions[@"name"];
        NSString * sap = rtpOptions[@"sap"];
        if( muxer )       [subOptions addObject:[NSString stringWithFormat:@"muxer=%@", muxer]];
        if( destination ) [subOptions addObject:[NSString stringWithFormat:@"dst=%@", destination]];
        if( sdp )      [subOptions addObject:[NSString stringWithFormat:@"sdp=%@", sdp]];
        if( sap )      [subOptions addObject:@"sap"];
        if( name )      [subOptions addObject:[NSString stringWithFormat:@"name=\"%@\"", name]];
        NSString *rtp = [NSString stringWithFormat:@"#rtp{%@}", [subOptions componentsJoinedByString:@","]];
        if ( !transcodingOptions )
            rtp = [NSString stringWithFormat:@"#%@", rtp];

        [optionsAsArray addObject:rtp];
        [subOptions removeAllObjects];
    }
    representedOptions = [optionsAsArray componentsJoinedByString:@":"];
    return representedOptions;
}
@end
