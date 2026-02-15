#import "../TagLibMetadataReader.h"

#include <tag.h>
#include <toolkit/tpropertymap.h>
#include <ape/apetag.h>
#include <trueaudio/trueaudiofile.h>
#include <tagutils.h>

namespace {

NSString *stringFromTagLib(const TagLib::String &value) {
    return value.isEmpty() ? nil : @(value.toCString(true));
}

TagLib::String firstPropertyValue(const TagLib::PropertyMap &properties,
                                  std::initializer_list<const char *> keys) {
    for (const auto &entry : properties) {
        const TagLib::String key = entry.first.upper();
        for (const auto *candidate : keys) {
            if (key == TagLib::String(candidate)) {
                const TagLib::StringList &values = entry.second;
                if (!values.isEmpty()) {
                    return values.front();
                }
            }
        }
    }
    return TagLib::String();
}

void fillMissingString(NSMutableDictionary *metadata,
                       NSString *field,
                       const TagLib::String &value) {
    if (!metadata[field]) {
        if (NSString *string = stringFromTagLib(value)) {
            metadata[field] = string;
        }
    }
}

void fillMissingNumber(NSMutableDictionary *metadata,
                       NSString *field,
                       NSInteger value) {
    if (!metadata[field] && value > 0) {
        metadata[field] = @(value);
    }
}

} // namespace

namespace TagLibMetadataReader {

void populateTagMetadata(NSMutableDictionary<NSString *, id> *metadata,
                         NSString *path,
                         TagLib::FileRef &file,
                         bool hasTagLibFile) {
    if (!hasTagLibFile) {
        return;
    }

    TagLib::Tag *tag = file.tag();

    fillMissingString(metadata, @"title", tag->title());
    fillMissingString(metadata, @"artist", tag->artist());
    fillMissingString(metadata, @"album", tag->album());
    fillMissingString(metadata, @"comment", tag->comment());
    fillMissingString(metadata, @"genre", tag->genre());
    fillMissingNumber(metadata, @"year", tag->year());
    fillMissingNumber(metadata, @"track", tag->track());

    if (TagLib::File *nativeFile = file.file()) {
        const TagLib::PropertyMap properties = nativeFile->properties();

        fillMissingString(metadata, @"title", firstPropertyValue(properties, {"TITLE"}));
        fillMissingString(metadata, @"artist", firstPropertyValue(properties, {"ARTIST", "ALBUMARTIST"}));
        fillMissingString(metadata, @"album", firstPropertyValue(properties, {"ALBUM"}));
        fillMissingString(metadata, @"comment", firstPropertyValue(properties, {"COMMENT", "DESCRIPTION"}));
        fillMissingString(metadata, @"genre", firstPropertyValue(properties, {"GENRE"}));

        const TagLib::String trackValue = firstPropertyValue(properties, {"TRACKNUMBER", "TRACK"});
        fillMissingNumber(metadata, @"track", trackValue.toInt());

        const TagLib::String yearValue = firstPropertyValue(properties, {"DATE", "YEAR"});
        fillMissingNumber(metadata, @"year", yearValue.toInt());

        NSString *lowercasedExtension = [[path pathExtension] lowercaseString];
        if ([lowercasedExtension isEqualToString:@"tta"]) {
            auto *trueAudioFile = dynamic_cast<TagLib::TrueAudio::File *>(nativeFile);
            if (trueAudioFile) {
                const TagLib::offset_t id3v1Location = TagLib::Utils::findID3v1(trueAudioFile);
                const TagLib::offset_t apeFooterLocation = TagLib::Utils::findAPE(trueAudioFile, id3v1Location);
                if (apeFooterLocation >= 0) {
                    TagLib::APE::Tag apeTag(trueAudioFile, apeFooterLocation);
                    fillMissingString(metadata, @"title", apeTag.title());
                    fillMissingString(metadata, @"artist", apeTag.artist());
                    fillMissingString(metadata, @"album", apeTag.album());
                    fillMissingString(metadata, @"comment", apeTag.comment());
                    fillMissingString(metadata, @"genre", apeTag.genre());
                    fillMissingNumber(metadata, @"track", apeTag.track());
                    fillMissingNumber(metadata, @"year", apeTag.year());
                }
            }
        }
    }
}

void populateAudioProperties(NSMutableDictionary<NSString *, id> *metadata,
                             TagLib::FileRef &file,
                             bool hasTagLibFile) {
    if (!hasTagLibFile || !file.audioProperties()) {
        return;
    }

    TagLib::AudioProperties *props = file.audioProperties();
    metadata[@"duration"] = @(props->lengthInSeconds());
    metadata[@"bitrate"] = @(props->bitrate());
    metadata[@"sampleRate"] = @(props->sampleRate());
    metadata[@"channels"] = @(props->channels());
}

} // namespace TagLibMetadataReader
