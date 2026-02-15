#import "AVFoundationFallback.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

namespace {

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
    NSURL *url = [NSURL fileURLWithPath:path];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];

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
    NSURL *url = [NSURL fileURLWithPath:path];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];

    if (!metadata[@"duration"]) {
        const Float64 seconds = CMTimeGetSeconds(asset.duration);
        if (isfinite(seconds) && seconds > 0) {
            metadata[@"duration"] = @((NSInteger)llround(seconds));
        }
    }

    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!audioTrack) {
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
}

@end
