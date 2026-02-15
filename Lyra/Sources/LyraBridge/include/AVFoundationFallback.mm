#import "AVFoundationFallback.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

namespace {

AVURLAsset *assetForPath(NSString *path) {
    NSDictionary<NSString *, id> *options = @{
        AVURLAssetPreferPreciseDurationAndTimingKey: @YES
    };
    NSURL *url = [NSURL fileURLWithPath:path];
    return [AVURLAsset URLAssetWithURL:url options:options];
}

BOOL loadAssetKeysSynchronously(AVAsset *asset,
                                NSArray<NSString *> *keys,
                                NSError **error) {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    for (NSString *key in keys) {
        NSError *keyError = nil;
        AVKeyValueStatus status = [asset statusOfValueForKey:key error:&keyError];
        if (status != AVKeyValueStatusLoaded) {
            if (error) {
                *error = keyError;
            }
            return NO;
        }
    }

    return YES;
}

BOOL isOggFamilyFile(NSString *path) {
    NSString *ext = path.pathExtension.lowercaseString;
    return [ext isEqualToString:@"oga"] || [ext isEqualToString:@"ogg"];
}

void logOggAudioFallbackIfNeeded(NSString *path,
                                 NSDictionary<NSString *, id> *metadata,
                                 AVAsset *asset,
                                 NSError *durationError,
                                 NSError *tracksError) {
    if (!isOggFamilyFile(path)) {
        return;
    }

    if (metadata[@"duration"] && metadata[@"bitrate"]) {
        return;
    }

    const BOOL preciseTiming = asset.providesPreciseDurationAndTiming;
    NSString *durationText = metadata[@"duration"] ? [metadata[@"duration"] description] : @"nil";
    NSString *bitrateText = metadata[@"bitrate"] ? [metadata[@"bitrate"] description] : @"nil";
    NSString *durationErrorText = durationError.localizedDescription ?: @"none";
    NSString *tracksErrorText = tracksError.localizedDescription ?: @"none";

    NSLog(@"[Lyra][AVFallback] OGG diagnostics for %@ -> duration=%@ bitrate=%@ preciseTiming=%@ durationError=%@ tracksError=%@", path.lastPathComponent, durationText, bitrateText, preciseTiming ? @"YES" : @"NO", durationErrorText, tracksErrorText);
}

NSString *normalizedMetadataKey(AVMetadataItem *item) {
    if (item.commonKey.length > 0) {
        return item.commonKey.lowercaseString;
    }
    if ([item.key isKindOfClass:NSString.class]) {
        return ((NSString *)item.key).lowercaseString;
    }
    return nil;
}

void fillFromAVMetadataItem(NSMutableDictionary *metadata, AVMetadataItem *item) {
    NSString *key = normalizedMetadataKey(item);
    NSString *value = item.stringValue;
    if (key.length == 0 || value.length == 0) {
        return;
    }

    if (([key isEqualToString:@"title"] || [key isEqualToString:@"name"]) && !metadata[@"title"]) {
        metadata[@"title"] = value;
    } else if (([key isEqualToString:@"artist"] || [key isEqualToString:@"author"] || [key isEqualToString:@"albumartist"]) && !metadata[@"artist"]) {
        metadata[@"artist"] = value;
    } else if (([key isEqualToString:@"album"] || [key isEqualToString:@"albumname"]) && !metadata[@"album"]) {
        metadata[@"album"] = value;
    } else if (([key isEqualToString:@"comment"] || [key isEqualToString:@"description"]) && !metadata[@"comment"]) {
        metadata[@"comment"] = value;
    } else if ([key isEqualToString:@"genre"] && !metadata[@"genre"]) {
        metadata[@"genre"] = value;
    } else if (([key isEqualToString:@"tracknumber"] || [key isEqualToString:@"track"]) && !metadata[@"track"]) {
        NSInteger track = value.integerValue;
        if (track > 0) {
            metadata[@"track"] = @(track);
        }
    } else if (([key isEqualToString:@"date"] || [key isEqualToString:@"year"]) && !metadata[@"year"]) {
        NSInteger year = value.integerValue;
        if (year > 0) {
            metadata[@"year"] = @(year);
        }
    }
}

} // namespace

@implementation AVFoundationFallback

+ (void)applyMetadataFallbackForPath:(NSString *)path
                            metadata:(NSMutableDictionary<NSString *, id> *)metadata {
    AVURLAsset *asset = assetForPath(path);

    for (AVMetadataItem *item in asset.commonMetadata) {
        fillFromAVMetadataItem(metadata, item);
    }

    for (AVMetadataFormat format in asset.availableMetadataFormats) {
        NSArray<AVMetadataItem *> *items = [asset metadataForFormat:format];
        for (AVMetadataItem *item in items) {
            fillFromAVMetadataItem(metadata, item);
        }
    }
}

+ (void)applyAudioPropertiesFallbackForPath:(NSString *)path
                                   metadata:(NSMutableDictionary<NSString *, id> *)metadata {
    AVURLAsset *asset = assetForPath(path);

    NSError *durationLoadError = nil;
    const BOOL durationReady = loadAssetKeysSynchronously(asset, @[@"duration"], &durationLoadError);

    if (!metadata[@"duration"] && durationReady) {
        const Float64 seconds = CMTimeGetSeconds(asset.duration);
        if (isfinite(seconds) && seconds > 0) {
            metadata[@"duration"] = @((NSInteger)llround(seconds));
        }
    }

    NSError *tracksLoadError = nil;
    const BOOL tracksReady = loadAssetKeysSynchronously(asset, @[@"tracks"], &tracksLoadError);

    if (!tracksReady) {
        logOggAudioFallbackIfNeeded(path, metadata, asset, durationLoadError, tracksLoadError);
        return;
    }

    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!audioTrack) {
        logOggAudioFallbackIfNeeded(path, metadata, asset, durationLoadError, tracksLoadError);
        return;
    }

    if (!metadata[@"bitrate"] && audioTrack.estimatedDataRate > 0) {
        metadata[@"bitrate"] = @((NSInteger)llround(audioTrack.estimatedDataRate / 1000.0));
    }

    const bool needsSampleRate = metadata[@"sampleRate"] == nil;
    const bool needsChannels = metadata[@"channels"] == nil;
    if (!needsSampleRate && !needsChannels) {
        return;
    }

    for (id description in audioTrack.formatDescriptions) {
        CMAudioFormatDescriptionRef audioDescription = (__bridge CMAudioFormatDescriptionRef)description;
        const AudioStreamBasicDescription *streamDescription =
            CMAudioFormatDescriptionGetStreamBasicDescription(audioDescription);
        if (!streamDescription) {
            continue;
        }

        if (!metadata[@"sampleRate"] && streamDescription->mSampleRate > 0) {
            metadata[@"sampleRate"] = @((NSInteger)llround(streamDescription->mSampleRate));
        }

        if (!metadata[@"channels"] && streamDescription->mChannelsPerFrame > 0) {
            metadata[@"channels"] = @((NSInteger)streamDescription->mChannelsPerFrame);
        }

        if (metadata[@"sampleRate"] && metadata[@"channels"]) {
            break;
        }
    }

    logOggAudioFallbackIfNeeded(path, metadata, asset, durationLoadError, tracksLoadError);
}

@end
