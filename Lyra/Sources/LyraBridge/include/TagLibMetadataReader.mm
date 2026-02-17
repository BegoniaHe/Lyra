#import "../TagLibMetadataReader.h"

#include <tag.h>
#include <fileref.h>
#include <audioproperties.h>
#include <toolkit/tpropertymap.h>
#include <toolkit/tvariant.h>
#include <ape/apetag.h>
#include <trueaudio/trueaudiofile.h>
#include <flac/flacfile.h>
#include <mpeg/mpegfile.h>
#include <mpeg/id3v2/id3v2tag.h>
#include <mpeg/id3v2/frames/attachedpictureframe.h>
#include <mp4/mp4file.h>
#include <mp4/mp4tag.h>
#include <mp4/mp4item.h>
#include <mp4/mp4coverart.h>
#include <tagutils.h>

namespace {

NSString *stringFromTagLib(const TagLib::String &value) {
    return value.isEmpty() ? nil : @(value.toCString(true));
}

TagLib::String canonicalize(const TagLib::String &value) {
    TagLib::String upper = value.upper();
    std::string source = upper.to8Bit(true);
    std::string normalized;
    normalized.reserve(source.size());
    for (char ch : source) {
        if (ch == '_' || ch == ' ' || ch == '-') {
            continue;
        }
        normalized.push_back(ch);
    }
    return TagLib::String(normalized, TagLib::String::UTF8);
}

TagLib::String firstPropertyValue(const TagLib::PropertyMap &properties,
                                  std::initializer_list<const char *> keys) {
    TagLib::List<TagLib::String> normalizedCandidates;
    for (const auto *candidate : keys) {
        normalizedCandidates.append(canonicalize(TagLib::String(candidate, TagLib::String::UTF8)));
    }

    for (const auto &entry : properties) {
        TagLib::String key = canonicalize(entry.first);
        bool matches = false;
        for (const auto &candidate : normalizedCandidates) {
            if (key == candidate) {
                matches = true;
                break;
            }
        }

        if (!matches) {
            continue;
        }

        const TagLib::StringList &values = entry.second;
        if (!values.isEmpty()) {
            return values.front();
        }
    }

    return TagLib::String();
}

NSInteger parsePositiveInteger(const TagLib::String &value) {
    if (value.isEmpty()) {
        return 0;
    }

    std::string text = value.to8Bit(true);
    size_t slash = text.find('/');
    std::string firstPart = slash == std::string::npos ? text : text.substr(0, slash);
    NSInteger number = (NSInteger)std::strtol(firstPart.c_str(), nullptr, 10);
    return number > 0 ? number : 0;
}

void parseNumberPair(const TagLib::String &value, NSInteger *number, NSInteger *total) {
    if (number) {
        *number = 0;
    }
    if (total) {
        *total = 0;
    }

    if (value.isEmpty()) {
        return;
    }

    std::string text = value.to8Bit(true);
    size_t slash = text.find('/');

    if (slash == std::string::npos) {
        NSInteger parsed = parsePositiveInteger(value);
        if (number) {
            *number = parsed;
        }
        return;
    }

    std::string first = text.substr(0, slash);
    std::string second = text.substr(slash + 1);
    NSInteger firstNumber = (NSInteger)std::strtol(first.c_str(), nullptr, 10);
    NSInteger secondNumber = (NSInteger)std::strtol(second.c_str(), nullptr, 10);

    if (number) {
        *number = firstNumber > 0 ? firstNumber : 0;
    }
    if (total) {
        *total = secondNumber > 0 ? secondNumber : 0;
    }
}

bool parseBool(const TagLib::String &value) {
    if (value.isEmpty()) {
        return false;
    }

    TagLib::String upper = value.upper();
    return upper == TagLib::String("1") ||
        upper == TagLib::String("TRUE") ||
        upper == TagLib::String("YES");
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

void fillString(NSMutableDictionary *metadata,
                NSString *field,
                const TagLib::String &value) {
    if (NSString *string = stringFromTagLib(value)) {
        metadata[field] = string;
    }
}

void fillMissingNumber(NSMutableDictionary *metadata,
                       NSString *field,
                       NSInteger value) {
    if (!metadata[field] && value > 0) {
        metadata[field] = @(value);
    }
}

void fillMissingStringFromProperty(NSMutableDictionary *metadata,
                                   NSString *field,
                                   const TagLib::PropertyMap &properties,
                                   std::initializer_list<const char *> keys) {
    const TagLib::String value = firstPropertyValue(properties, keys);
    fillMissingString(metadata, field, value);
}

void fillMissingNumberFromProperty(NSMutableDictionary *metadata,
                                   NSString *field,
                                   const TagLib::PropertyMap &properties,
                                   std::initializer_list<const char *> keys) {
    const TagLib::String value = firstPropertyValue(properties, keys);
    NSInteger parsed = parsePositiveInteger(value);
    fillMissingNumber(metadata, field, parsed);
}

void fillMissingBoolFromProperty(NSMutableDictionary *metadata,
                                 NSString *field,
                                 const TagLib::PropertyMap &properties,
                                 std::initializer_list<const char *> keys) {
    const TagLib::String value = firstPropertyValue(properties, keys);
    if (value.isEmpty() || metadata[field]) {
        return;
    }

    metadata[field] = @(parseBool(value));
}

NSString *codecForExtension(NSString *path) {
    NSString *ext = path.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"mp3"] || [ext isEqualToString:@"mp2"]) return @"MP3";
    if ([ext isEqualToString:@"m4a"] || [ext isEqualToString:@"m4b"] || [ext isEqualToString:@"m4p"] || [ext isEqualToString:@"mp4"] || [ext isEqualToString:@"aac"]) return @"AAC";
    if ([ext isEqualToString:@"flac"]) return @"FLAC";
    if ([ext isEqualToString:@"ogg"]) return @"Vorbis";
    if ([ext isEqualToString:@"oga"]) return @"OGG FLAC";
    if ([ext isEqualToString:@"opus"]) return @"Opus";
    if ([ext isEqualToString:@"wav"]) return @"WAV";
    if ([ext isEqualToString:@"aiff"] || [ext isEqualToString:@"aif"]) return @"AIFF";
    if ([ext isEqualToString:@"ape"]) return @"APE";
    if ([ext isEqualToString:@"wv"]) return @"WavPack";
    if ([ext isEqualToString:@"tta"]) return @"TrueAudio";
    if ([ext isEqualToString:@"mpc"]) return @"Musepack";
    if ([ext isEqualToString:@"spx"]) return @"Speex";
    if ([ext isEqualToString:@"wma"] || [ext isEqualToString:@"asf"]) return @"WMA";
    if ([ext isEqualToString:@"dsf"]) return @"DSF";
    if ([ext isEqualToString:@"dff"]) return @"DSDIFF";
    if ([ext isEqualToString:@"webm"]) return @"WebM";
    if ([ext isEqualToString:@"caf"]) return @"CAF";
    return nil;
}

void fillBitDepthIfAvailable(NSMutableDictionary *metadata,
                             NSString *path,
                             TagLib::File *nativeFile) {
    if (metadata[@"bitDepth"] || !nativeFile) {
        return;
    }

    NSString *ext = path.pathExtension.lowercaseString;
    int bitDepth = 0;

    if ([ext isEqualToString:@"flac"]) {
        if (auto *flac = dynamic_cast<TagLib::FLAC::File *>(nativeFile)) {
            if (flac->audioProperties()) {
                bitDepth = flac->audioProperties()->bitsPerSample();
            }
        }
    } else if ([ext isEqualToString:@"tta"]) {
        if (auto *tta = dynamic_cast<TagLib::TrueAudio::File *>(nativeFile)) {
            if (tta->audioProperties()) {
                bitDepth = tta->audioProperties()->bitsPerSample();
            }
        }
    }

    if (bitDepth > 0) {
        metadata[@"bitDepth"] = @(bitDepth);
    }
}

void fillArtworkFromComplexProperties(NSMutableDictionary *metadata,
                                      TagLib::File *nativeFile) {
    if (metadata[@"artworkData"] || !nativeFile) {
        return;
    }

    TagLib::List<TagLib::VariantMap> pictures = nativeFile->complexProperties("PICTURE");
    if (pictures.isEmpty()) {
        return;
    }

    const TagLib::VariantMap *selected = nullptr;
    for (auto it = pictures.begin(); it != pictures.end(); ++it) {
        auto typeIt = it->find("pictureType");
        if (typeIt != it->end()) {
            TagLib::String type = typeIt->second.toString();
            if (type.upper().find("FRONT") != -1) {
                selected = &(*it);
                break;
            }
        }
    }

    if (!selected) {
        selected = &pictures.front();
    }

    auto dataIt = selected->find("data");
    if (dataIt == selected->end()) {
        return;
    }

    TagLib::ByteVector data = dataIt->second.toByteVector();
    if (data.isEmpty()) {
        return;
    }

    metadata[@"artworkData"] = [NSData dataWithBytes:data.data() length:data.size()];
    auto mimeIt = selected->find("mimeType");
    if (mimeIt != selected->end()) {
        fillString(metadata, @"artworkMimeType", mimeIt->second.toString());
    }
}

void fillArtworkFromID3v2(NSMutableDictionary *metadata,
                          NSString *path) {
    if (metadata[@"artworkData"] || ![path.pathExtension.lowercaseString isEqualToString:@"mp3"]) {
        return;
    }

    TagLib::MPEG::File mpegFile(path.fileSystemRepresentation);
    if (!mpegFile.isValid() || !mpegFile.ID3v2Tag()) {
        return;
    }

    TagLib::ID3v2::AttachedPictureFrame *selectedFrame = nullptr;
    auto frames = mpegFile.ID3v2Tag()->frameList("APIC");
    for (auto it = frames.begin(); it != frames.end(); ++it) {
        auto *frame = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(*it);
        if (!frame) {
            continue;
        }

        if (!selectedFrame) {
            selectedFrame = frame;
        }

        if (frame->type() == TagLib::ID3v2::AttachedPictureFrame::FrontCover) {
            selectedFrame = frame;
            break;
        }
    }

    if (!selectedFrame) {
        return;
    }

    TagLib::ByteVector picture = selectedFrame->picture();
    if (picture.isEmpty()) {
        return;
    }

    metadata[@"artworkData"] = [NSData dataWithBytes:picture.data() length:picture.size()];
    fillString(metadata, @"artworkMimeType", selectedFrame->mimeType());
}

void fillArtworkFromMP4(NSMutableDictionary *metadata,
                        NSString *path) {
    if (metadata[@"artworkData"]) {
        return;
    }

    NSString *ext = path.pathExtension.lowercaseString;
    if (!([ext isEqualToString:@"m4a"] || [ext isEqualToString:@"m4b"] || [ext isEqualToString:@"m4p"] || [ext isEqualToString:@"mp4"])) {
        return;
    }

    TagLib::MP4::File mp4File(path.fileSystemRepresentation);
    if (!mp4File.isValid() || !mp4File.tag()) {
        return;
    }

    auto items = mp4File.tag()->itemMap();
    if (!items.contains("covr")) {
        return;
    }

    TagLib::MP4::CoverArtList covers = items["covr"].toCoverArtList();
    if (covers.isEmpty()) {
        return;
    }

    TagLib::MP4::CoverArt cover = covers.front();
    TagLib::ByteVector data = cover.data();
    if (data.isEmpty()) {
        return;
    }

    metadata[@"artworkData"] = [NSData dataWithBytes:data.data() length:data.size()];
    switch (cover.format()) {
        case TagLib::MP4::CoverArt::PNG:
            metadata[@"artworkMimeType"] = @"image/png";
            break;
        case TagLib::MP4::CoverArt::BMP:
            metadata[@"artworkMimeType"] = @"image/bmp";
            break;
        case TagLib::MP4::CoverArt::GIF:
            metadata[@"artworkMimeType"] = @"image/gif";
            break;
        case TagLib::MP4::CoverArt::JPEG:
        default:
            metadata[@"artworkMimeType"] = @"image/jpeg";
            break;
    }
}

void fillArtworkFromFLAC(NSMutableDictionary *metadata,
                         NSString *path) {
    if (metadata[@"artworkData"] || ![path.pathExtension.lowercaseString isEqualToString:@"flac"]) {
        return;
    }

    TagLib::FLAC::File flacFile(path.fileSystemRepresentation);
    if (!flacFile.isValid()) {
        return;
    }

    const TagLib::List<TagLib::FLAC::Picture *> &pictures = flacFile.pictureList();
    if (pictures.isEmpty()) {
        return;
    }

    TagLib::FLAC::Picture *selected = nullptr;
    for (auto it = pictures.begin(); it != pictures.end(); ++it) {
        if ((*it)->type() == TagLib::FLAC::Picture::FrontCover) {
            selected = *it;
            break;
        }
    }

    if (!selected) {
        selected = pictures.front();
    }

    if (!selected) {
        return;
    }

    TagLib::ByteVector data = selected->data();
    if (data.isEmpty()) {
        return;
    }

    metadata[@"artworkData"] = [NSData dataWithBytes:data.data() length:data.size()];
    fillString(metadata, @"artworkMimeType", selected->mimeType());
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
    fillMissingNumber(metadata, @"trackNumber", tag->track());

    if (TagLib::File *nativeFile = file.file()) {
        const TagLib::PropertyMap properties = nativeFile->properties();

        fillMissingString(metadata, @"title", firstPropertyValue(properties, {"TITLE"}));
        fillMissingString(metadata, @"artist", firstPropertyValue(properties, {"ARTIST", "ALBUMARTIST"}));
        fillMissingString(metadata, @"album", firstPropertyValue(properties, {"ALBUM"}));
        fillMissingString(metadata, @"comment", firstPropertyValue(properties, {"COMMENT", "DESCRIPTION"}));
        fillMissingString(metadata, @"genre", firstPropertyValue(properties, {"GENRE"}));

        fillMissingStringFromProperty(metadata, @"albumArtist", properties, {"ALBUMARTIST", "ALBUM ARTIST"});
        fillMissingStringFromProperty(metadata, @"composer", properties, {"COMPOSER"});
        fillMissingStringFromProperty(metadata, @"sortTitle", properties, {"TITLESORT", "SORTTITLE"});
        fillMissingStringFromProperty(metadata, @"sortArtist", properties, {"ARTISTSORT", "SORTARTIST"});
        fillMissingStringFromProperty(metadata, @"sortAlbum", properties, {"ALBUMSORT", "SORTALBUM"});
        fillMissingStringFromProperty(metadata, @"sortAlbumArtist", properties, {"ALBUMARTISTSORT", "SORTALBUMARTIST"});
        fillMissingStringFromProperty(metadata, @"sortComposer", properties, {"COMPOSERSORT", "SORTCOMPOSER"});

        NSInteger trackNumber = 0;
        NSInteger totalTracks = 0;
        const TagLib::String trackValue = firstPropertyValue(properties, {"TRACKNUMBER", "TRACK"});
        parseNumberPair(trackValue, &trackNumber, &totalTracks);
        fillMissingNumber(metadata, @"track", trackNumber);
        fillMissingNumber(metadata, @"trackNumber", trackNumber);
        fillMissingNumber(metadata, @"totalTracks", totalTracks);

        fillMissingNumberFromProperty(metadata, @"totalTracks", properties, {"TRACKTOTAL", "TOTALTRACKS"});
        fillMissingNumberFromProperty(metadata, @"discNumber", properties, {"DISCNUMBER", "DISC"});
        fillMissingNumberFromProperty(metadata, @"totalDiscs", properties, {"DISCTOTAL", "TOTALDISCS"});
        fillMissingNumberFromProperty(metadata, @"bpm", properties, {"BPM"});

        const TagLib::String yearValue = firstPropertyValue(properties, {"DATE", "YEAR"});
        fillMissingNumber(metadata, @"year", yearValue.toInt());

        fillMissingStringFromProperty(metadata, @"releaseDate", properties, {"RELEASEDATE", "DATE"});
        fillMissingStringFromProperty(metadata, @"originalReleaseDate", properties, {"ORIGINALDATE", "ORIGINALRELEASEDATE"});
        fillMissingStringFromProperty(metadata, @"lyrics", properties, {"LYRICS", "UNSYNCEDLYRICS"});
        fillMissingStringFromProperty(metadata, @"isrc", properties, {"ISRC"});
        fillMissingStringFromProperty(metadata, @"label", properties, {"LABEL", "PUBLISHER", "ORGANIZATION"});
        fillMissingStringFromProperty(metadata, @"encodedBy", properties, {"ENCODEDBY", "ENCODER"});
        fillMissingStringFromProperty(metadata, @"encoderSettings", properties, {"ENCODERSETTINGS"});
        fillMissingStringFromProperty(metadata, @"copyright", properties, {"COPYRIGHT"});

        fillMissingStringFromProperty(metadata, @"musicBrainzArtistId", properties, {"MUSICBRAINZ_ARTISTID"});
        fillMissingStringFromProperty(metadata, @"musicBrainzAlbumId", properties, {"MUSICBRAINZ_ALBUMID"});
        fillMissingStringFromProperty(metadata, @"musicBrainzTrackId", properties, {"MUSICBRAINZ_TRACKID"});
        fillMissingStringFromProperty(metadata, @"musicBrainzReleaseGroupId", properties, {"MUSICBRAINZ_RELEASEGROUPID"});

        fillMissingStringFromProperty(metadata, @"replayGainTrack", properties, {"REPLAYGAIN_TRACK_GAIN"});
        fillMissingStringFromProperty(metadata, @"replayGainAlbum", properties, {"REPLAYGAIN_ALBUM_GAIN"});

        fillMissingStringFromProperty(metadata, @"subtitle", properties, {"SUBTITLE", "TIT3"});
        fillMissingStringFromProperty(metadata, @"grouping", properties, {"GROUPING", "CONTENTGROUP"});
        fillMissingStringFromProperty(metadata, @"movement", properties, {"MOVEMENT"});
        fillMissingStringFromProperty(metadata, @"mood", properties, {"MOOD"});
        fillMissingStringFromProperty(metadata, @"language", properties, {"LANGUAGE"});
        fillMissingStringFromProperty(metadata, @"key", properties, {"INITIALKEY", "KEY"});

        fillMissingBoolFromProperty(metadata, @"compilation", properties, {"COMPILATION", "TCMP"});

        if (!metadata[@"codec"]) {
            NSString *codec = codecForExtension(path);
            if (codec.length > 0) {
                metadata[@"codec"] = codec;
            }
        }

        fillBitDepthIfAvailable(metadata, path, nativeFile);

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
                    fillMissingNumber(metadata, @"trackNumber", apeTag.track());
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

    const int duration = props->lengthInSeconds();
    if (duration > 0) {
        metadata[@"duration"] = @(duration);
    }

    const int bitrate = props->bitrate();
    if (bitrate > 0) {
        metadata[@"bitrate"] = @(bitrate);
    }

    const int sampleRate = props->sampleRate();
    if (sampleRate > 0) {
        metadata[@"sampleRate"] = @(sampleRate);
    }

    const int channels = props->channels();
    if (channels > 0) {
        metadata[@"channels"] = @(channels);
    }
}

void populateExtendedMetadata(NSMutableDictionary<NSString *, id> *metadata,
                              NSString *path,
                              TagLib::FileRef &file,
                              bool hasTagLibFile) {
    if (!hasTagLibFile) {
        return;
    }

    TagLib::File *nativeFile = file.file();
    if (!nativeFile) {
        return;
    }

    fillArtworkFromComplexProperties(metadata, nativeFile);
    fillArtworkFromID3v2(metadata, path);
    fillArtworkFromMP4(metadata, path);
    fillArtworkFromFLAC(metadata, path);
}

} // namespace TagLibMetadataReader
