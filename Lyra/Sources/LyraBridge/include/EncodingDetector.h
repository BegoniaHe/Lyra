#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EncodingDetector : NSObject

+ (void)installTagLibStringHandlers;
+ (void)applyAIFFChunkFallbackForPath:(NSString *)path
                             metadata:(NSMutableDictionary<NSString *, id> *)metadata;

@end

NS_ASSUME_NONNULL_END
