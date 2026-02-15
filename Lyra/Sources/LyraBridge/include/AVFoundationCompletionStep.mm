#import "AVFoundationCompletionStep.h"

#import "AVFoundationFallback.h"

@implementation LYRAVFoundationCompletionStep

- (void)applyToMetadata:(NSMutableDictionary<NSString *, id> *)metadata
                   path:(NSString *)path
           hasTagLibFile:(bool)hasTagLibFile
                fileRef:(TagLib::FileRef *)fileRef {
    (void)hasTagLibFile;
    (void)fileRef;
    [AVFoundationFallback applyMetadataFallbackForPath:path metadata:metadata];
    [AVFoundationFallback applyAudioPropertiesFallbackForPath:path metadata:metadata];
}

@end
