#import "XiphOggMetadataReader.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

namespace {

struct OggProbeResult {
    bool parsedHeader = false;
    bool isVorbis = false;
    bool isOpus = false;
    int sampleRate = 0;
    int channels = 0;
    int preSkip = 0;
    int64_t lastGranulePosition = -1;
    uint64_t fileByteCount = 0;
};

bool isOggFamilyFile(NSString *path) {
    NSString *extension = path.pathExtension.lowercaseString;
    return [extension isEqualToString:@"ogg"] || [extension isEqualToString:@"oga"];
}

int readLE32(const unsigned char *buffer) {
    return (int)buffer[0] |
        ((int)buffer[1] << 8) |
        ((int)buffer[2] << 16) |
        ((int)buffer[3] << 24);
}

int readLE16(const unsigned char *buffer) {
    return (int)buffer[0] | ((int)buffer[1] << 8);
}

int64_t readLE64Signed(const unsigned char *buffer) {
    uint64_t value = 0;
    for (int i = 0; i < 8; i++) {
        value |= ((uint64_t)buffer[i]) << (i * 8);
    }
    return (int64_t)value;
}

void parseCodecHeader(OggProbeResult &result, const std::vector<unsigned char> &packet) {
    if (packet.size() >= 16 &&
        packet[0] == 0x01 &&
        std::memcmp(packet.data() + 1, "vorbis", 6) == 0) {
        result.parsedHeader = true;
        result.isVorbis = true;
        result.channels = packet[11];
        result.sampleRate = readLE32(packet.data() + 12);
        return;
    }

    if (packet.size() >= 19 && std::memcmp(packet.data(), "OpusHead", 8) == 0) {
        result.parsedHeader = true;
        result.isOpus = true;
        result.channels = packet[9];
        result.preSkip = readLE16(packet.data() + 10);
        result.sampleRate = 48000;
    }
}

bool probeOggFile(NSString *path, OggProbeResult &result) {
    FILE *file = std::fopen(path.fileSystemRepresentation, "rb");
    if (!file) {
        return false;
    }

    if (std::fseek(file, 0, SEEK_END) == 0) {
        long byteCount = std::ftell(file);
        if (byteCount > 0) {
            result.fileByteCount = (uint64_t)byteCount;
        }
        std::rewind(file);
    }

    bool success = true;
    bool foundAnyPage = false;
    bool hasTargetSerial = false;
    uint32_t targetSerial = 0;
    std::vector<unsigned char> packetBuffer;

    while (true) {
        unsigned char pageHeader[27];
        const size_t headerRead = std::fread(pageHeader, 1, sizeof(pageHeader), file);

        if (headerRead == 0 && std::feof(file)) {
            break;
        }

        if (headerRead != sizeof(pageHeader)) {
            success = false;
            break;
        }

        if (std::memcmp(pageHeader, "OggS", 4) != 0) {
            success = false;
            break;
        }

        foundAnyPage = true;

        const unsigned char headerType = pageHeader[5];
        const int64_t granulePosition = readLE64Signed(pageHeader + 6);
        const uint32_t serial = (uint32_t)readLE32(pageHeader + 14);
        const unsigned char segmentCount = pageHeader[26];

        std::vector<unsigned char> lacing(segmentCount);
        if (segmentCount > 0) {
            if (std::fread(lacing.data(), 1, segmentCount, file) != segmentCount) {
                success = false;
                break;
            }
        }

        size_t bodySize = 0;
        for (unsigned char segment : lacing) {
            bodySize += segment;
        }

        std::vector<unsigned char> body(bodySize);
        if (bodySize > 0 && std::fread(body.data(), 1, bodySize, file) != bodySize) {
            success = false;
            break;
        }

        if (!hasTargetSerial) {
            if ((headerType & 0x02) == 0) {
                continue;
            }
            targetSerial = serial;
            hasTargetSerial = true;
        }

        if (serial != targetSerial) {
            continue;
        }

        if (granulePosition > 0) {
            result.lastGranulePosition = granulePosition;
        }

        if (result.parsedHeader) {
            continue;
        }

        size_t bodyOffset = 0;
        for (unsigned char segment : lacing) {
            if (segment > 0) {
                packetBuffer.insert(packetBuffer.end(), body.begin() + bodyOffset, body.begin() + bodyOffset + segment);
            }
            bodyOffset += segment;

            if (segment < 255) {
                parseCodecHeader(result, packetBuffer);
                packetBuffer.clear();
                if (result.parsedHeader) {
                    break;
                }
            }
        }
    }

    std::fclose(file);

    return success && foundAnyPage;
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

void fillEstimatedBitrateIfNeeded(uint64_t fileByteCount,
                                  NSMutableDictionary<NSString *, id> *metadata,
                                  NSInteger duration) {
    if (!shouldFillValue(metadata[@"bitrate"]) || duration <= 0) {
        return;
    }

    if (fileByteCount == 0) {
        return;
    }

    long double bitrate = ((long double)fileByteCount * 8.0L) /
        (long double)duration / 1000.0L;
    if (!std::isfinite((double)bitrate) || bitrate <= 0.0L) {
        return;
    }

    metadata[@"bitrate"] = @((NSInteger)llround((double)bitrate));
}

} // namespace

@implementation XiphOggMetadataReader

+ (void)applyPreferredOggParsingForPath:(NSString *)path
                               metadata:(NSMutableDictionary<NSString *, id> *)metadata {
    if (!isOggFamilyFile(path)) {
        return;
    }

    OggProbeResult result;
    if (!probeOggFile(path, result)) {
        return;
    }

    if (result.sampleRate > 0 && shouldFillValue(metadata[@"sampleRate"])) {
        metadata[@"sampleRate"] = @(result.sampleRate);
    }

    if (result.channels > 0 && shouldFillValue(metadata[@"channels"])) {
        metadata[@"channels"] = @(result.channels);
    }

    if (result.lastGranulePosition > 0 && result.sampleRate > 0 && shouldFillValue(metadata[@"duration"])) {
        int64_t samples = result.lastGranulePosition;
        if (result.isOpus) {
            samples = std::max<int64_t>(0, samples - result.preSkip);
        }

        long double durationSeconds = (long double)samples / (long double)result.sampleRate;
        if (std::isfinite((double)durationSeconds) && durationSeconds > 0.0L) {
            NSInteger duration = (NSInteger)llround((double)durationSeconds);
            if (duration > 0) {
                metadata[@"duration"] = @(duration);
                fillEstimatedBitrateIfNeeded(result.fileByteCount, metadata, duration);
            }
        }
    }

    NSNumber *duration = metadata[@"duration"];
    if ([duration isKindOfClass:NSNumber.class] && [duration integerValue] > 0) {
        fillEstimatedBitrateIfNeeded(result.fileByteCount, metadata, [duration integerValue]);
    }
}

@end
