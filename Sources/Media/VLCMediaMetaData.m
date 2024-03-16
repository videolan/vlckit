/*****************************************************************************
 * VLCMediaMetaData.m: VLCKit.framework VLCMediaMetaData implementation
 *****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
 * $Id$
 *
 * Authors:
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

#import <VLCMedia.h>
#import <VLCLibVLCBridging.h>

@implementation VLCMediaMetaData
{
    __weak VLCMedia *_media;
    NSMutableDictionary *_metaCache;
    VLCPlatformImage * _Nullable _artwork;
    dispatch_queue_t _metaCacheAccessQueue;
}

- (instancetype)initWithMedia:(VLCMedia *)media
{
    if (self = [super init]) {
        _media = media;
        _metaCache = [NSMutableDictionary dictionary];
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT,
                                                                             QOS_CLASS_UTILITY,
                                                                             0);
        _metaCacheAccessQueue = dispatch_queue_create("VLCKit.VLCMediaMetaData.metaCacheAccessQueue", attr);
    }
    return self;
}

- (void)setTitle:(nullable NSString *)title
{
    [self setString: title forKey: libvlc_meta_Title];
}

- (nullable NSString *)title
{
    return [self stringForKey: libvlc_meta_Title];
}

- (void)setArtist:(nullable NSString *)artist
{
    [self setString: artist forKey: libvlc_meta_Artist];
}

- (nullable NSString *)artist
{
    return [self stringForKey: libvlc_meta_Artist];
}

- (void)setGenre:(nullable NSString *)genre
{
    [self setString: genre forKey: libvlc_meta_Genre];
}

- (nullable NSString *)genre
{
    return [self stringForKey: libvlc_meta_Genre];
}

- (void)setCopyright:(nullable NSString *)copyright
{
    [self setString: copyright forKey: libvlc_meta_Copyright];
}

- (nullable NSString *)copyright
{
    return [self stringForKey: libvlc_meta_Copyright];
}

- (void)setAlbum:(nullable NSString *)album
{
    [self setString: album forKey: libvlc_meta_Album];
}

- (nullable NSString *)album
{
    return [self stringForKey: libvlc_meta_Album];
}

- (void)setTrackNumber:(unsigned)trackNumber
{
    [self setUnsigned: trackNumber forKey: libvlc_meta_TrackNumber];
}

- (unsigned)trackNumber
{
    return [self unsignedForKey: libvlc_meta_TrackNumber];
}

- (void)setMetaDescription:(nullable NSString *)metaDescription
{
    [self setString: metaDescription forKey: libvlc_meta_Description];
}

- (nullable NSString *)metaDescription
{
    return [self stringForKey: libvlc_meta_Description];
}

- (void)setRating:(nullable NSString *)rating
{
    [self setString: rating forKey: libvlc_meta_Rating];
}

- (nullable NSString *)rating
{
    return [self stringForKey: libvlc_meta_Rating];
}

- (void)setDate:(nullable NSString *)date
{
    [self setString: date forKey: libvlc_meta_Date];
}

- (nullable NSString *)date
{
    return [self stringForKey: libvlc_meta_Date];
}

- (void)setSetting:(NSString *)setting
{
    [self setString: setting forKey: libvlc_meta_Setting];
}

- (nullable NSString *)setting
{
    return [self stringForKey: libvlc_meta_Setting];
}

- (void)setUrl:(nullable NSURL *)url
{
    [self setURL: url forKey: libvlc_meta_URL];
}

- (nullable NSURL *)url
{
    return [self urlForKey: libvlc_meta_URL];
}

- (void)setLanguage:(nullable NSString *)language
{
    [self setString: language forKey: libvlc_meta_Language];
}

- (nullable NSString *)language
{
    return [self stringForKey: libvlc_meta_Language];
}

- (void)setNowPlaying:(nullable NSString *)nowPlaying
{
    [self setString: nowPlaying forKey: libvlc_meta_NowPlaying];
}

- (nullable NSString *)nowPlaying
{
    return [self stringForKey: libvlc_meta_NowPlaying];
}

- (void)setPublisher:(nullable NSString *)publisher
{
    [self setString: publisher forKey: libvlc_meta_Publisher];
}

- (nullable NSString *)publisher
{
    return [self stringForKey: libvlc_meta_Publisher];
}

- (void)setEncodedBy:(nullable NSString *)encodedBy
{
    [self setString: encodedBy forKey: libvlc_meta_EncodedBy];
}

- (nullable NSString *)encodedBy
{
    return [self stringForKey: libvlc_meta_EncodedBy];
}

- (void)setArtworkURL:(nullable NSURL *)artworkURL
{
    [self setURL: artworkURL forKey: libvlc_meta_ArtworkURL];
}

- (nullable NSURL *)artworkURL
{
    return [self urlForKey: libvlc_meta_ArtworkURL];
}

- (void)setTrackID:(unsigned)trackID
{
    [self setUnsigned: trackID forKey: libvlc_meta_TrackID];
}

- (unsigned)trackID
{
    return [self unsignedForKey: libvlc_meta_TrackID];
}

- (void)setTrackTotal:(unsigned)trackTotal
{
    [self setUnsigned: trackTotal forKey: libvlc_meta_TrackTotal];
}

- (unsigned)trackTotal
{
    return [self unsignedForKey: libvlc_meta_TrackTotal];
}

- (void)setDirector:(nullable NSString *)director
{
    [self setString: director forKey: libvlc_meta_Director];
}

- (nullable NSString *)director
{
    return [self stringForKey: libvlc_meta_Director];
}

- (void)setSeason:(unsigned)season
{
    [self setUnsigned: season forKey: libvlc_meta_Season];
}

- (unsigned)season
{
    return [self unsignedForKey: libvlc_meta_Season];
}

- (void)setEpisode:(unsigned)episode
{
    [self setUnsigned: episode forKey: libvlc_meta_Episode];
}

- (unsigned)episode
{
    return [self unsignedForKey: libvlc_meta_Episode];
}

- (void)setShowName:(nullable NSString *)showName
{
    [self setString: showName forKey: libvlc_meta_ShowName];
}

- (nullable NSString *)showName
{
    return [self stringForKey: libvlc_meta_ShowName];
}

- (void)setActors:(nullable NSString *)actors
{
    [self setString: actors forKey: libvlc_meta_Actors];
}

- (nullable NSString *)actors
{
    return [self stringForKey: libvlc_meta_Actors];
}

- (void)setAlbumArtist:(nullable NSString *)albumArtist
{
    [self setString: albumArtist forKey: libvlc_meta_AlbumArtist];
}

- (nullable NSString *)albumArtist
{
    return [self stringForKey: libvlc_meta_AlbumArtist];
}

- (void)setDiscNumber:(unsigned)discNumber
{
    [self setUnsigned: discNumber forKey: libvlc_meta_DiscNumber];
}

- (unsigned)discNumber
{
    return [self unsignedForKey: libvlc_meta_DiscNumber];
}

- (void)setDiscTotal:(unsigned)discTotal
{
    [self setUnsigned: discTotal forKey: libvlc_meta_DiscTotal];
}

- (unsigned)discTotal
{
    return [self unsignedForKey: libvlc_meta_DiscTotal];
}

- (nullable VLCPlatformImage *)artwork
{
    if (!_artwork) {
        NSURL *artURL = self.artworkURL;
        if (artURL.isFileURL) {
            _artwork = [[VLCPlatformImage alloc] initWithContentsOfFile: artURL.path];
        }
    }
    return _artwork;
}

- (nullable NSString *)extraValueForKey:(NSString *)key
{
    return [self extraCacheValueForKey: key];
}

- (void)setExtraValue:(nullable NSString *)value forKey:(NSString *)key
{
    [self setMetaExtra: value forKey: key];
}

- (nullable NSDictionary<NSString *, NSString *> *)extra
{
    libvlc_media_t *media_t = (libvlc_media_t *)_media.libVLCMediaDescriptor;
    if (!media_t)
        return nil;
    
    char **ppsz_names = NULL;
    const unsigned count = libvlc_media_get_meta_extra_names(media_t, &ppsz_names);
    if (count == 0)
        return nil;
    
    NSMutableDictionary<NSString *, NSString *> *extra = [NSMutableDictionary dictionaryWithCapacity: (NSUInteger)count];
    for (unsigned i = 0; i < count; i++) {
        NSString *key = @(ppsz_names[i]);
        NSString *value = [self extraCacheValueForKey: key];
        if (value)
            extra[key] = value;
    }
    
    libvlc_media_meta_extra_names_release(ppsz_names, count);
    
    return extra;
}

- (BOOL)save
{
    libvlc_media_t *media_t = (libvlc_media_t *)_media.libVLCMediaDescriptor;
    return media_t ? libvlc_media_save_meta([VLCLibrary sharedLibrary].instance, media_t) != 0 : NO;
}

- (void)prefetch
{
    // 26 = `libvlc_meta_t` all count
    for (libvlc_meta_t meta_t = 0; meta_t < 26; meta_t++)
        [self fetchMetaDataForKey: meta_t];
}

- (void)clearCache
{
    dispatch_barrier_async(_metaCacheAccessQueue, ^{
        [_metaCache removeAllObjects];
    });
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>, title: %@, artist: %@, genre: %@, copyright: %@, album: %@, trackNumber: %u, metaDescription: %@, rating: %@, date: %@, setting: %@, url: %@, language: %@, nowPlaying: %@, publisher: %@, encodedBy: %@, artworkURL: %@, trackID: %u, trackTotal: %u, director: %@, season: %u, episode: %u, showName: %@, actors: %@, albumArtist: %@, discNumber: %u, discTotal: %u, extra: %@", [self class], self, [self title], [self artist], [self genre], [self copyright], [self album], [self trackNumber], [self metaDescription], [self rating], [self date], [self setting], [self url], [self language], [self nowPlaying], [self publisher], [self encodedBy], [self artworkURL], [self trackID], [self trackTotal], [self director], [self season], [self episode], [self showName], [self actors], [self albumArtist], [self discNumber], [self discTotal], [self extra]];
}


- (void)handleMediaMetaChanged:(const libvlc_meta_t)type
{
    [self fetchMetaDataForKey: type];
}

/* fetch and cache */

- (nullable id)fetchMetaDataForKey:(const libvlc_meta_t)key
{
    id value = nil;
    
    switch (key) {
            
        // NSString
        case libvlc_meta_Title:
        case libvlc_meta_Artist:
        case libvlc_meta_Genre:
        case libvlc_meta_Copyright:
        case libvlc_meta_Album:
        case libvlc_meta_Description:
        case libvlc_meta_Rating:
        case libvlc_meta_Date:
        case libvlc_meta_Setting:
        case libvlc_meta_Language:
        case libvlc_meta_NowPlaying:
        case libvlc_meta_Publisher:
        case libvlc_meta_EncodedBy:
        case libvlc_meta_Director:
        case libvlc_meta_ShowName:
        case libvlc_meta_Actors:
        case libvlc_meta_AlbumArtist:
            value = [self metadataStringForKey: key];
            break;
            
        // NSNumber
        case libvlc_meta_TrackNumber:
        case libvlc_meta_TrackID:
        case libvlc_meta_TrackTotal:
        case libvlc_meta_Season:
        case libvlc_meta_Episode:
        case libvlc_meta_DiscNumber:
        case libvlc_meta_DiscTotal:
            value = [self metadataNumberForKey: key];
            break;
            
        // NSURL
        case libvlc_meta_URL:
        case libvlc_meta_ArtworkURL:
            value = [self metadataURLForKey: key];
            break;
            
        default:
            VKLog(@"WARNING: undefined meta type : %d", key);
            break;
    }
    
    if (value)
        dispatch_barrier_async(_metaCacheAccessQueue, ^{
            _metaCache[@(key)] = value;
        });
    
    return value;
}

/* cache get */

- (nullable id)cacheValueForKey:(const libvlc_meta_t)key
{
    __block id cacheValue = nil;
    dispatch_sync(_metaCacheAccessQueue, ^{
        cacheValue = _metaCache[@(key)];
    });
    
    if (!cacheValue)
        cacheValue = [self fetchMetaDataForKey: key];
    
    return cacheValue;
}

- (nullable NSString *)stringForKey:(const libvlc_meta_t)key
{
    id cacheValue = [self cacheValueForKey: key];
    if ([cacheValue isKindOfClass: NSString.class])
        return (NSString *)cacheValue;
    
    return nil;
}

- (nullable NSURL *)urlForKey:(const libvlc_meta_t)key
{
    id cacheValue = [self cacheValueForKey: key];
    if ([cacheValue isKindOfClass: NSURL.class])
        return (NSURL *)cacheValue;
    
    return nil;
}

- (unsigned)unsignedForKey:(const libvlc_meta_t)key
{
    id cacheValue = [self cacheValueForKey: key];
    if ([cacheValue isKindOfClass: NSNumber.class])
        return [(NSNumber *)cacheValue unsignedIntValue];
    
    return 0;
}


/* internal meta get */

- (nullable id)metadataStringForKey:(const libvlc_meta_t)key
{
    libvlc_media_t *media_t = (libvlc_media_t *)_media.libVLCMediaDescriptor;
    if (!media_t)
        return nil;

    char *value = libvlc_media_get_meta(media_t, key);
    if (!value)
        return NSNull.null;

    NSString *str = @(value);
    free(value);

    return str;
}

- (nullable id)metadataURLForKey:(const libvlc_meta_t)key
{
    libvlc_media_t *media_t = (libvlc_media_t *)_media.libVLCMediaDescriptor;
    if (!media_t)
        return nil;

    char *value = libvlc_media_get_meta(media_t, key);
    if (!value)
        return NSNull.null;

    NSString *str = @(value);
    free(value);

    return str ? [NSURL URLWithString: str] : nil;
}

- (nullable id)metadataNumberForKey:(const libvlc_meta_t)key
{
    libvlc_media_t *media_t = (libvlc_media_t *)_media.libVLCMediaDescriptor;
    if (!media_t)
        return nil;

    char *value = libvlc_media_get_meta(media_t, key);
    if (!value)
        return NSNull.null;

    NSNumber *num = @(atoi(value));
    free(value);

    return num;
}

/* internal meta set */

- (void)setMetadata:(const char *)data forKey:(const libvlc_meta_t)key
{
    libvlc_media_t *media_t = (libvlc_media_t *)_media.libVLCMediaDescriptor;
    if (!media_t)
        return;
    
    libvlc_media_set_meta(media_t, key, data);
    
    dispatch_barrier_async(_metaCacheAccessQueue, ^{
        [_metaCache removeObjectForKey: @(key)];
    });
}

- (void)setString:(nullable NSString *)str forKey:(const libvlc_meta_t)key
{
    [self setMetadata: str.UTF8String forKey: key];
}

- (void)setURL:(nullable NSURL *)url forKey:(const libvlc_meta_t)key
{
    [self setString: url.absoluteString forKey: key];
}

- (void)setUnsigned:(const unsigned)u forKey:(const libvlc_meta_t)key
{
    const size_t size = 11;
    char value[size];
    snprintf(value, size, "%u", u);
    [self setMetadata: value forKey: key];
}

/* extra cache get */
- (nullable NSString *)extraCacheValueForKey:(NSString *)key
{
    if (!key)
        return nil;
    
    __block id cacheValue = nil;
    dispatch_sync(_metaCacheAccessQueue, ^{
        cacheValue = _metaCache[key];
    });
    
    if (!cacheValue && (cacheValue = [self metaExtraForKey: key]))
        dispatch_barrier_async(_metaCacheAccessQueue, ^{
            _metaCache[key] = cacheValue;
        });
    
    if ([cacheValue isKindOfClass: NSString.class])
        return (NSString *)cacheValue;
    
    return nil;
}

/* internal meta extra get */
- (nullable id)metaExtraForKey:(NSString *)key
{
    if (!key)
        return nil;
    
    libvlc_media_t *media_t = (libvlc_media_t *)_media.libVLCMediaDescriptor;
    if (!media_t)
        return nil;
    
    char *value = libvlc_media_get_meta_extra(media_t, key.UTF8String);
    if (!value)
        return NSNull.null;
    
    NSString *extraValue = @(value);
    free(value);
    
    return extraValue;
}

/* internal meta extra set */
- (void)setMetaExtra:(nullable NSString *)value forKey:(NSString *)key
{
    if (!key)
        return;
    
    libvlc_media_t *media_t = (libvlc_media_t *)_media.libVLCMediaDescriptor;
    if (!media_t)
        return;
    
    libvlc_media_set_meta_extra(media_t, key.UTF8String, value.UTF8String);
    
    dispatch_barrier_async(_metaCacheAccessQueue, ^{
        [_metaCache removeObjectForKey: key];
    });
}

@end
