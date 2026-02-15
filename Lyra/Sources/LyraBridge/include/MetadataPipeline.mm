#import "MetadataPipeline.h"

#import "SpecializedParserStep.h"
#import "TagLibParserStep.h"
#import "AVFoundationCompletionStep.h"
#import "InvalidValueSanitizationStep.h"

NSArray<id<LYRMetadataPipelineStep>> *LYRCreateMetadataPipelineSteps(void) {
    static NSArray<id<LYRMetadataPipelineStep>> *steps;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        steps = @[
            [LYRSpecializedParserStep new],
            [LYRTagLibParserStep new],
            [LYRAVFoundationCompletionStep new],
            [LYRInvalidValueSanitizationStep new]
        ];
    });
    return steps;
}
