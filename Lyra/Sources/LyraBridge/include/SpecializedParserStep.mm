#import "SpecializedParserStep.h"

#import "EncodingDetector.h"
#import "XiphOggMetadataReader.h"

@implementation LYRSpecializedParserStep

- (void)applyToMetadata:(NSMutableDictionary<NSString *, id> *)metadata
                   path:(NSString *)path
           hasTagLibFile:(bool)hasTagLibFile
                fileRef:(TagLib::FileRef *)fileRef {
    (void)hasTagLibFile;
    (void)fileRef;
    [EncodingDetector applyAIFFChunkFallbackForPath:path metadata:metadata];
    [XiphOggMetadataReader applyPreferredOggParsingForPath:path metadata:metadata];
}

@end
