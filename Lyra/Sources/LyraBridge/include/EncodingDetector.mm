#import "EncodingDetector.h"

#include <_foundation_unicode/ucsdet.h>
#include <mpeg/id3v1/id3v1tag.h>
#include <mpeg/id3v2/id3v2tag.h>
#include <riff/wav/infotag.h>

namespace {

enum class EncodingProfile {
  ID3v1,
  WAVInfo,
  AIFFText,
  ID3v2Latin1Fallback,
};

NSData *normalizedData(const TagLib::ByteVector &data) {
  if (data.isEmpty()) {
    return nil;
  }

  const char *raw = data.data();
  NSUInteger len = static_cast<NSUInteger>(data.size());
  while (len > 0 && raw[len - 1] == '\0') {
    len--;
  }
  if (len == 0) {
    return nil;
  }
  return [NSData dataWithBytes:raw length:len];
}

NSStringEncoding encodingFromIANA(NSString *ianaName) {
  if (ianaName.length == 0) {
    return 0;
  }
  CFStringEncoding cfEncoding =
      CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)ianaName);
  if (cfEncoding == kCFStringEncodingInvalidId) {
    return 0;
  }
  return CFStringConvertEncodingToNSStringEncoding(cfEncoding);
}

NSString *decodeDataWithIANA(NSData *data, NSString *ianaName) {
  NSStringEncoding encoding = encodingFromIANA(ianaName);
  if (encoding == 0) {
    return nil;
  }
  return [[NSString alloc] initWithData:data encoding:encoding];
}

NSString *decodeUTF8Fast(NSData *data) {
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

NSArray<NSString *> *fallbackEncodingsForProfile(EncodingProfile profile) {
  switch (profile) {
  case EncodingProfile::ID3v1:
    return @[
      @"UTF-8", @"windows-1252", @"ISO-8859-1", @"Shift_JIS", @"windows-1251",
      @"Big5"
    ];
  case EncodingProfile::WAVInfo:
    return @[ @"UTF-8", @"windows-1252", @"ISO-8859-1" ];
  case EncodingProfile::AIFFText:
    return @[ @"UTF-8", @"windows-1252", @"ISO-8859-1" ];
  case EncodingProfile::ID3v2Latin1Fallback:
    return @[ @"UTF-8", @"windows-1252", @"ISO-8859-1" ];
  }
}

NSString *decodeWithICU(NSData *data, EncodingProfile profile) {
  UErrorCode status = U_ZERO_ERROR;
  UCharsetDetector *detector = ucsdet_open(&status);
  if (U_FAILURE(status) || detector == nullptr) {
    return nil;
  }

  const char *bytes = static_cast<const char *>(data.bytes);
  int32_t length = static_cast<int32_t>(data.length);
  status = U_ZERO_ERROR;
  ucsdet_setText(detector, bytes, length, &status);
  if (U_FAILURE(status)) {
    ucsdet_close(detector);
    return nil;
  }

  for (NSString *encoding in fallbackEncodingsForProfile(profile)) {
    status = U_ZERO_ERROR;
    ucsdet_setDetectableCharset(detector, encoding.UTF8String, true, &status);
  }

  status = U_ZERO_ERROR;
  const UCharsetMatch *match = ucsdet_detect(detector, &status);
  if (U_FAILURE(status) || match == nullptr) {
    ucsdet_close(detector);
    return nil;
  }

  status = U_ZERO_ERROR;
  int32_t confidence = ucsdet_getConfidence(match, &status);
  if (U_FAILURE(status) || confidence < 20) {
    ucsdet_close(detector);
    return nil;
  }

  status = U_ZERO_ERROR;
  const char *detected = ucsdet_getName(match, &status);
  if (U_FAILURE(status) || detected == nullptr) {
    ucsdet_close(detector);
    return nil;
  }

  NSString *decoded = decodeDataWithIANA(data, @(detected));
  ucsdet_close(detector);
  return decoded;
}

TagLib::String taglibStringFromNSString(NSString *value) {
  if (value.length == 0) {
    return TagLib::String();
  }
  return TagLib::String(value.UTF8String, TagLib::String::UTF8);
}

NSString *smartDecode(const TagLib::ByteVector &data, EncodingProfile profile) {
  NSData *source = normalizedData(data);
  if (!source) {
    return nil;
  }

  if (NSString *utf8 = decodeUTF8Fast(source)) {
    return utf8;
  }

  if (NSString *icuDetected = decodeWithICU(source, profile)) {
    return icuDetected;
  }

  for (NSString *encoding in fallbackEncodingsForProfile(profile)) {
    if (NSString *decoded = decodeDataWithIANA(source, encoding)) {
      return decoded;
    }
  }

  return nil;
}

NSString *smartDecodeData(NSData *source, EncodingProfile profile) {
  if (!source || source.length == 0) {
    return nil;
  }

  TagLib::ByteVector buffer(static_cast<const char *>(source.bytes),
                            static_cast<unsigned int>(source.length));
  return smartDecode(buffer, profile);
}

BOOL isLikelyMojibake(NSString *value) {
  if (value.length == 0) {
    return NO;
  }

  NSUInteger latinSupplementCount = 0;
  NSUInteger cjkCount = 0;
  NSUInteger printableCount = 0;
  for (NSUInteger i = 0; i < value.length; i++) {
    unichar c = [value characterAtIndex:i];
    if ([[NSCharacterSet controlCharacterSet] characterIsMember:c] &&
        c != '\n' && c != '\r' && c != '\t') {
      continue;
    }
    printableCount++;
    if (c >= 0x0080 && c <= 0x00FF) {
      latinSupplementCount++;
    }
    if (c >= 0x2E80 && c <= 0x9FFF) {
      cjkCount++;
    }
  }

  if (printableCount == 0) {
    return NO;
  }

  const double latinRatio = static_cast<double>(latinSupplementCount) /
                            static_cast<double>(printableCount);
  return latinRatio >= 0.4 && cjkCount == 0;
}

void fillStringWithRepair(NSMutableDictionary *metadata, NSString *field,
                          NSString *decodedValue) {
  if (decodedValue.length == 0) {
    return;
  }

  NSString *existing = metadata[field];
  if (!existing.length) {
    metadata[field] = decodedValue;
    return;
  }

  if (isLikelyMojibake(existing) && !isLikelyMojibake(decodedValue)) {
    metadata[field] = decodedValue;
  }
}

uint32_t readBigEndianUInt32(const uint8_t *bytes) {
  return (static_cast<uint32_t>(bytes[0]) << 24) |
         (static_cast<uint32_t>(bytes[1]) << 16) |
         (static_cast<uint32_t>(bytes[2]) << 8) |
         static_cast<uint32_t>(bytes[3]);
}

class SmartID3v1StringHandler final : public TagLib::ID3v1::StringHandler {
public:
  TagLib::String parse(const TagLib::ByteVector &data) const override {
    if (NSString *decoded = smartDecode(data, EncodingProfile::ID3v1)) {
      return taglibStringFromNSString(decoded);
    }
    return TagLib::ID3v1::StringHandler::parse(data);
  }
};

class SmartRIFFInfoStringHandler final
    : public TagLib::RIFF::Info::StringHandler {
public:
  TagLib::String parse(const TagLib::ByteVector &data) const override {
    if (NSString *decoded = smartDecode(data, EncodingProfile::WAVInfo)) {
      return taglibStringFromNSString(decoded);
    }
    return TagLib::RIFF::Info::StringHandler::parse(data);
  }
};

class SmartID3v2Latin1Handler final
    : public TagLib::ID3v2::Latin1StringHandler {
public:
  TagLib::String parse(const TagLib::ByteVector &data) const override {
    if (NSString *decoded =
            smartDecode(data, EncodingProfile::ID3v2Latin1Fallback)) {
      return taglibStringFromNSString(decoded);
    }
    return TagLib::ID3v2::Latin1StringHandler::parse(data);
  }
};

} // namespace

@implementation EncodingDetector

+ (void)installTagLibStringHandlers {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    static SmartID3v1StringHandler id3v1Handler;
    static SmartRIFFInfoStringHandler riffInfoHandler;
    static SmartID3v2Latin1Handler id3v2Latin1Handler;

    TagLib::ID3v1::Tag::setStringHandler(&id3v1Handler);
    TagLib::RIFF::Info::Tag::setStringHandler(&riffInfoHandler);
    TagLib::ID3v2::Tag::setLatin1StringHandler(&id3v2Latin1Handler);
  });
}

+ (void)applyAIFFChunkFallbackForPath:(NSString *)path
                             metadata:(NSMutableDictionary<NSString *, id> *)
                                          metadata {
  NSString *ext = [[path pathExtension] lowercaseString];
  if (!([ext isEqualToString:@"aif"] || [ext isEqualToString:@"aiff"] ||
        [ext isEqualToString:@"aifc"])) {
    return;
  }

  NSData *fileData = [NSData dataWithContentsOfFile:path
                                            options:NSDataReadingMappedIfSafe
                                              error:nil];
  if (fileData.length < 12) {
    return;
  }

  const uint8_t *bytes = static_cast<const uint8_t *>(fileData.bytes);
  if (memcmp(bytes, "FORM", 4) != 0) {
    return;
  }
  if (!(memcmp(bytes + 8, "AIFF", 4) == 0 ||
        memcmp(bytes + 8, "AIFC", 4) == 0)) {
    return;
  }

  NSUInteger offset = 12;
  while (offset + 8 <= fileData.length) {
    const uint8_t *chunkHeader = bytes + offset;
    const uint32_t chunkSize = readBigEndianUInt32(chunkHeader + 4);
    offset += 8;

    if (offset + static_cast<NSUInteger>(chunkSize) > fileData.length) {
      break;
    }

    NSData *chunkData = [NSData dataWithBytes:(bytes + offset)
                                       length:chunkSize];
    NSString *decoded = smartDecodeData(chunkData, EncodingProfile::AIFFText);

    if (memcmp(chunkHeader, "NAME", 4) == 0) {
      fillStringWithRepair(metadata, @"title", decoded);
    } else if (memcmp(chunkHeader, "AUTH", 4) == 0) {
      fillStringWithRepair(metadata, @"artist", decoded);
    } else if (memcmp(chunkHeader, "ANNO", 4) == 0) {
      fillStringWithRepair(metadata, @"comment", decoded);
    }

    offset += chunkSize;
    if ((chunkSize & 1U) != 0 && offset < fileData.length) {
      offset += 1;
    }
  }
}

@end
