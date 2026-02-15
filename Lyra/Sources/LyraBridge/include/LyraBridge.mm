#import "LyraBridge.h"
#import "EncodingDetector.h"
#import "AVFoundationFallback.h"
#import "../TagLibMetadataReader.h"
#include <fileref.h>

namespace {

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

    TagLibMetadataReader::populateTagMetadata(metadata, path, file, hasTagLibFile);

    [EncodingDetector applyAIFFChunkFallbackForPath:path metadata:metadata];

    [AVFoundationFallback applyMetadataFallbackForPath:path metadata:metadata];

    [AVFoundationFallback applyAudioPropertiesFallbackForPath:path metadata:metadata];
    
    if (!hasTagLibFile && metadata.count == 0) {
        return nil;
    }
    
    TagLibMetadataReader::populateAudioProperties(metadata, file, hasTagLibFile);
    
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
    
    return file.save();
}

+ (NSArray<NSString *> *)supportedFileExtensions {
    return @[@"mp3", @"flac", @"ogg", @"oga", @"opus", @"m4a", @"mp4",
             @"ape", @"wv", @"mpc", @"tta", @"wav", @"aiff", @"aif",
             @"dsf", @"dff", @"wma", @"asf", @"webm", @"caf"];
}

@end
