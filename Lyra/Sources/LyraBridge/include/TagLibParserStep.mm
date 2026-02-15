#import "TagLibParserStep.h"

#import "MetadataSanitizer.h"
#import "../TagLibMetadataReader.h"

@implementation LYRTagLibParserStep

- (void)applyToMetadata:(NSMutableDictionary<NSString *, id> *)metadata
                   path:(NSString *)path
           hasTagLibFile:(bool)hasTagLibFile
                fileRef:(TagLib::FileRef *)fileRef {
    if (!fileRef) {
        return;
    }

    TagLibMetadataReader::populateTagMetadata(metadata, path, *fileRef, hasTagLibFile);
    if (!LYRIsOggFamilyPath(path)) {
        TagLibMetadataReader::populateAudioProperties(metadata, *fileRef, hasTagLibFile);
    }
}

@end
