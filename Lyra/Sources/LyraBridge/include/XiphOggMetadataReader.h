#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XiphOggMetadataReader : NSObject

+ (void)applyPreferredOggParsingForPath:(NSString *)path
                               metadata:(NSMutableDictionary<NSString *, id> *)metadata;

@end

NS_ASSUME_NONNULL_END
