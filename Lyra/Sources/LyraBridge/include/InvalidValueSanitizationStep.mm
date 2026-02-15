#import "InvalidValueSanitizationStep.h"

#import "MetadataSanitizer.h"

@implementation LYRInvalidValueSanitizationStep

- (void)applyToMetadata:(NSMutableDictionary<NSString *, id> *)metadata
                   path:(NSString *)path
           hasTagLibFile:(bool)hasTagLibFile
                fileRef:(TagLib::FileRef *)fileRef {
    (void)path;
    (void)hasTagLibFile;
    (void)fileRef;
    (void)LYRSanitizeInvalidMetadataValues(metadata);
}

@end
