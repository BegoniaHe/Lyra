#import <Foundation/Foundation.h>
#import "EncodingDetector.h"
#import "AVFoundationFallback.h"

NS_ASSUME_NONNULL_BEGIN

@interface LyraBridge : NSObject

+ (nullable NSDictionary<NSString *, id> *)readMetadataFromFile:(NSString *)path;
+ (BOOL)writeMetadata:(NSDictionary<NSString *, id> *)metadata toFile:(NSString *)path;
+ (nullable NSArray<NSString *> *)supportedFileExtensions;

@end

NS_ASSUME_NONNULL_END
