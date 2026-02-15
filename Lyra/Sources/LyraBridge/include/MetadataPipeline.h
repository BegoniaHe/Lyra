#import <Foundation/Foundation.h>

#ifdef __cplusplus
#include <fileref.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol LYRMetadataPipelineStep <NSObject>

- (void)applyToMetadata:(NSMutableDictionary<NSString *, id> *)metadata
                   path:(NSString *)path
           hasTagLibFile:(bool)hasTagLibFile
                fileRef:(TagLib::FileRef *)fileRef;

@end

NSArray<id<LYRMetadataPipelineStep>> *LYRCreateMetadataPipelineSteps(void);

NS_ASSUME_NONNULL_END
