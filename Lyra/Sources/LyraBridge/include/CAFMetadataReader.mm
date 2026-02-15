#import "CAFMetadataReader.h"

#import <AudioToolbox/AudioToolbox.h>

namespace {

bool isCAFFile(NSString *path) {
    return [path.pathExtension.lowercaseString isEqualToString:@"caf"];
}

bool shouldFillValue(id value) {
    if (!value) {
        return true;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [value integerValue] <= 0;
    }
    return false;
}

} // namespace

@implementation CAFMetadataReader

+ (void)applyPreferredCAFParsingForPath:(NSString *)path
                               metadata:(NSMutableDictionary<NSString *, id> *)metadata {
    if (!isCAFFile(path) || !shouldFillValue(metadata[@"bitrate"])) {
        return;
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    AudioFileID audioFile = nullptr;
    OSStatus openStatus = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &audioFile);
    if (openStatus != noErr || audioFile == nullptr) {
        return;
    }

    UInt32 bitRateBps = 0;
    UInt32 size = sizeof(bitRateBps);
    OSStatus bitRateStatus = AudioFileGetProperty(audioFile, kAudioFilePropertyBitRate, &size, &bitRateBps);
    (void)AudioFileClose(audioFile);

    if (bitRateStatus != noErr || size != sizeof(bitRateBps) || bitRateBps == 0) {
        return;
    }

    metadata[@"bitrate"] = @((NSInteger)(bitRateBps / 1000));
}

@end
