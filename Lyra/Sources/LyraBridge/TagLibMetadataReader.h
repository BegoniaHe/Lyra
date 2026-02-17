#import <Foundation/Foundation.h>

#ifdef __cplusplus
#include <fileref.h>

namespace TagLibMetadataReader {

void populateTagMetadata(NSMutableDictionary<NSString *, id> *metadata,
                         NSString *path,
                         TagLib::FileRef &file,
                         bool hasTagLibFile);

void populateAudioProperties(NSMutableDictionary<NSString *, id> *metadata,
                             TagLib::FileRef &file,
                             bool hasTagLibFile);

void populateExtendedMetadata(NSMutableDictionary<NSString *, id> *metadata,
                              NSString *path,
                              TagLib::FileRef &file,
                              bool hasTagLibFile);

} // namespace TagLibMetadataReader
#endif
