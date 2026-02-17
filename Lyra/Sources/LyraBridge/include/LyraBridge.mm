#import "LyraBridge.h"
#import "EncodingDetector.h"
#import "MetadataPipeline.h"
#include <fileref.h>
#include <tag.h>
#include <toolkit/tfile.h>
#include <toolkit/tpropertymap.h>

namespace {

bool isNonEmptyString(id value) {
    return [value isKindOfClass:NSString.class] && [((NSString *)value) length] > 0;
}

TagLib::String toTagString(NSString *value) {
    return TagLib::String(value.UTF8String, TagLib::String::UTF8);
}

void setPropertyIfPresent(TagLib::PropertyMap &properties,
                          NSDictionary<NSString *, id> *metadata,
                          NSString *jsonKey,
                          const char *tagKey) {
    id value = metadata[jsonKey];
    if (!isNonEmptyString(value)) {
        return;
    }

    properties.replace(tagKey, TagLib::StringList(toTagString((NSString *)value)));
}

void setNumericPropertyIfPresent(TagLib::PropertyMap &properties,
                                 NSDictionary<NSString *, id> *metadata,
                                 NSString *jsonKey,
                                 const char *tagKey) {
    id value = metadata[jsonKey];
    if (![value isKindOfClass:NSNumber.class]) {
        return;
    }

    NSInteger number = [(NSNumber *)value integerValue];
    if (number <= 0) {
        return;
    }

    NSString *stringValue = [NSString stringWithFormat:@"%ld", (long)number];
    properties.replace(tagKey, TagLib::StringList(toTagString(stringValue)));
}

void setBoolPropertyIfPresent(TagLib::PropertyMap &properties,
                              NSDictionary<NSString *, id> *metadata,
                              NSString *jsonKey,
                              const char *tagKey) {
    id value = metadata[jsonKey];
    if (![value isKindOfClass:NSNumber.class]) {
        return;
    }

    NSString *stringValue = [((NSNumber *)value) boolValue] ? @"1" : @"0";
    properties.replace(tagKey, TagLib::StringList(toTagString(stringValue)));
}

}

@implementation LyraBridge

+ (void)initialize {
    if (self == LyraBridge.class) {
        [EncodingDetector installTagLibStringHandlers];
    }
}

+ (NSDictionary<NSString *, id> *)readMetadataFromFile:(NSString *)path {
    [EncodingDetector installTagLibStringHandlers];

    TagLib::FileRef file([path UTF8String]);
    const bool hasTagLibFile = !file.isNull() && file.tag();
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];

    for (id<LYRMetadataPipelineStep> step in LYRCreateMetadataPipelineSteps()) {
        [step applyToMetadata:metadata
                         path:path
                 hasTagLibFile:hasTagLibFile
                      fileRef:&file];
    }

    if (!hasTagLibFile && metadata.count == 0) {
        return nil;
    }
    
    return [metadata copy];
}

+ (BOOL)writeMetadata:(NSDictionary<NSString *, id> *)metadata toFile:(NSString *)path {
    TagLib::FileRef file([path UTF8String]);
    
    if (file.isNull() || !file.tag()) {
        return NO;
    }
    
    TagLib::Tag *tag = file.tag();
    
    if (metadata[@"title"]) {
        tag->setTitle(TagLib::String([metadata[@"title"] UTF8String], TagLib::String::UTF8));
    }
    if (metadata[@"artist"]) {
        tag->setArtist(TagLib::String([metadata[@"artist"] UTF8String], TagLib::String::UTF8));
    }
    if (metadata[@"album"]) {
        tag->setAlbum(TagLib::String([metadata[@"album"] UTF8String], TagLib::String::UTF8));
    }
    if (metadata[@"comment"]) {
        tag->setComment(TagLib::String([metadata[@"comment"] UTF8String], TagLib::String::UTF8));
    }
    if (metadata[@"genre"]) {
        tag->setGenre(TagLib::String([metadata[@"genre"] UTF8String], TagLib::String::UTF8));
    }
    if (metadata[@"year"]) {
        tag->setYear([metadata[@"year"] unsignedIntValue]);
    }
    if (metadata[@"track"]) {
        tag->setTrack([metadata[@"track"] unsignedIntValue]);
    }

    TagLib::File *nativeFile = file.file();
    if (nativeFile) {
        TagLib::PropertyMap properties = nativeFile->properties();

        setPropertyIfPresent(properties, metadata, @"albumArtist", "ALBUMARTIST");
        setPropertyIfPresent(properties, metadata, @"composer", "COMPOSER");
        setPropertyIfPresent(properties, metadata, @"sortTitle", "TITLESORT");
        setPropertyIfPresent(properties, metadata, @"sortArtist", "ARTISTSORT");
        setPropertyIfPresent(properties, metadata, @"sortAlbum", "ALBUMSORT");
        setPropertyIfPresent(properties, metadata, @"sortAlbumArtist", "ALBUMARTISTSORT");
        setPropertyIfPresent(properties, metadata, @"sortComposer", "COMPOSERSORT");

        setNumericPropertyIfPresent(properties, metadata, @"trackNumber", "TRACKNUMBER");
        setNumericPropertyIfPresent(properties, metadata, @"totalTracks", "TRACKTOTAL");
        setNumericPropertyIfPresent(properties, metadata, @"discNumber", "DISCNUMBER");
        setNumericPropertyIfPresent(properties, metadata, @"totalDiscs", "DISCTOTAL");
        setNumericPropertyIfPresent(properties, metadata, @"bpm", "BPM");

        setPropertyIfPresent(properties, metadata, @"releaseDate", "RELEASEDATE");
        setPropertyIfPresent(properties, metadata, @"originalReleaseDate", "ORIGINALDATE");
        setPropertyIfPresent(properties, metadata, @"lyrics", "LYRICS");
        setPropertyIfPresent(properties, metadata, @"isrc", "ISRC");
        setPropertyIfPresent(properties, metadata, @"label", "LABEL");
        setPropertyIfPresent(properties, metadata, @"encodedBy", "ENCODEDBY");
        setPropertyIfPresent(properties, metadata, @"encoderSettings", "ENCODERSETTINGS");
        setPropertyIfPresent(properties, metadata, @"copyright", "COPYRIGHT");
        setPropertyIfPresent(properties, metadata, @"musicBrainzArtistId", "MUSICBRAINZ_ARTISTID");
        setPropertyIfPresent(properties, metadata, @"musicBrainzAlbumId", "MUSICBRAINZ_ALBUMID");
        setPropertyIfPresent(properties, metadata, @"musicBrainzTrackId", "MUSICBRAINZ_TRACKID");
        setPropertyIfPresent(properties, metadata, @"musicBrainzReleaseGroupId", "MUSICBRAINZ_RELEASEGROUPID");
        setPropertyIfPresent(properties, metadata, @"replayGainTrack", "REPLAYGAIN_TRACK_GAIN");
        setPropertyIfPresent(properties, metadata, @"replayGainAlbum", "REPLAYGAIN_ALBUM_GAIN");
        setPropertyIfPresent(properties, metadata, @"subtitle", "SUBTITLE");
        setPropertyIfPresent(properties, metadata, @"grouping", "GROUPING");
        setPropertyIfPresent(properties, metadata, @"movement", "MOVEMENT");
        setPropertyIfPresent(properties, metadata, @"mood", "MOOD");
        setPropertyIfPresent(properties, metadata, @"language", "LANGUAGE");
        setPropertyIfPresent(properties, metadata, @"key", "INITIALKEY");
        setBoolPropertyIfPresent(properties, metadata, @"compilation", "COMPILATION");

        nativeFile->setProperties(properties);
    }
    
    return file.save();
}

+ (NSArray<NSString *> *)supportedFileExtensions {
    return @[@"mp3", @"flac", @"ogg", @"oga", @"opus", @"m4a", @"mp4",
             @"ape", @"wv", @"mpc", @"tta", @"wav", @"aiff", @"aif",
             @"dsf", @"dff", @"wma", @"asf", @"webm", @"caf"];
}

@end
