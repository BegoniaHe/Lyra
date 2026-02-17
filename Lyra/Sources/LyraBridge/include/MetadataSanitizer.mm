#import "MetadataSanitizer.h"

namespace {

NSArray<NSString *> *stringMetadataFields() {
    return @[
        @"title", @"artist", @"album", @"albumArtist", @"composer",
        @"comment", @"genre", @"releaseDate", @"originalReleaseDate",
        @"lyrics", @"sortTitle", @"sortArtist", @"sortAlbum", @"sortAlbumArtist", @"sortComposer",
        @"codec", @"artworkMimeType", @"isrc", @"label", @"encodedBy", @"encoderSettings", @"copyright",
        @"musicBrainzArtistId", @"musicBrainzAlbumId", @"musicBrainzTrackId", @"musicBrainzReleaseGroupId",
        @"replayGainTrack", @"replayGainAlbum", @"subtitle", @"grouping", @"movement", @"mood", @"language", @"key"
    ];
}

NSArray<NSString *> *numericMetadataFields() {
    return @[@"year", @"track", @"trackNumber", @"totalTracks", @"discNumber", @"totalDiscs", @"bpm", @"duration", @"bitrate", @"sampleRate", @"channels", @"bitDepth"];
}

NSArray<NSString *> *booleanMetadataFields() {
    return @[@"compilation"];
}

NSString *trimmedNonEmptyString(id value) {
    if (![value isKindOfClass:NSString.class]) {
        return nil;
    }

    NSString *trimmed = [((NSString *)value) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length > 0 ? trimmed : nil;
}

NSInteger validatedPositiveInteger(id value) {
    if (![value isKindOfClass:NSNumber.class]) {
        return 0;
    }

    NSInteger integerValue = [(NSNumber *)value integerValue];
    return integerValue > 0 ? integerValue : 0;
}

NSNumber *validatedBoolean(id value) {
    if ([value isKindOfClass:NSNumber.class]) {
        return @([(NSNumber *)value boolValue]);
    }

    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized = [((NSString *)value) lowercaseString];
        if ([normalized isEqualToString:@"true"] ||
            [normalized isEqualToString:@"yes"] ||
            [normalized isEqualToString:@"1"]) {
            return @YES;
        }
        if ([normalized isEqualToString:@"false"] ||
            [normalized isEqualToString:@"no"] ||
            [normalized isEqualToString:@"0"]) {
            return @NO;
        }
    }

    return nil;
}

} // namespace

bool LYRIsOggFamilyPath(NSString *path) {
    NSString *extension = path.pathExtension.lowercaseString;
    return [extension isEqualToString:@"ogg"] || [extension isEqualToString:@"oga"];
}

bool LYRSanitizeInvalidMetadataValues(NSMutableDictionary<NSString *, id> *metadata) {
    bool hadInvalidValue = false;

    for (NSString *field in stringMetadataFields()) {
        id rawValue = metadata[field];
        if (!rawValue) {
            continue;
        }

        NSString *sanitizedValue = trimmedNonEmptyString(rawValue);
        if (!sanitizedValue) {
            [metadata removeObjectForKey:field];
            hadInvalidValue = true;
            continue;
        }

        if (![rawValue isEqual:sanitizedValue]) {
            metadata[field] = sanitizedValue;
        }
    }

    for (NSString *field in numericMetadataFields()) {
        id rawValue = metadata[field];
        if (!rawValue) {
            continue;
        }

        NSInteger sanitizedValue = validatedPositiveInteger(rawValue);
        if (sanitizedValue <= 0) {
            [metadata removeObjectForKey:field];
            hadInvalidValue = true;
            continue;
        }

        if ([rawValue integerValue] != sanitizedValue) {
            metadata[field] = @(sanitizedValue);
        }
    }

    for (NSString *field in booleanMetadataFields()) {
        id rawValue = metadata[field];
        if (!rawValue) {
            continue;
        }

        NSNumber *sanitizedValue = validatedBoolean(rawValue);
        if (!sanitizedValue) {
            [metadata removeObjectForKey:field];
            hadInvalidValue = true;
            continue;
        }

        if (![rawValue isEqual:sanitizedValue]) {
            metadata[field] = sanitizedValue;
        }
    }

    return hadInvalidValue;
}
