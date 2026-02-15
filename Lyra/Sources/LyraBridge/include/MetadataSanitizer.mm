#import "MetadataSanitizer.h"

namespace {

NSArray<NSString *> *stringMetadataFields() {
    return @[@"title", @"artist", @"album", @"comment", @"genre"];
}

NSArray<NSString *> *numericMetadataFields() {
    return @[@"year", @"track", @"duration", @"bitrate", @"sampleRate", @"channels"];
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

    return hadInvalidValue;
}
