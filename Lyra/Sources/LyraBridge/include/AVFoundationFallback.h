#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVFoundationFallback : NSObject

+ (void)applyMetadataFallbackForPath:(NSString *)path
                            metadata:(NSMutableDictionary<NSString *, id> *)metadata;

+ (void)applyAudioPropertiesFallbackForPath:(NSString *)path
                                   metadata:(NSMutableDictionary<NSString *, id> *)metadata;

@end

NS_ASSUME_NONNULL_END
