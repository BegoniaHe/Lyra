import Testing
@testable import Lyra

struct LyraHongYiYeTests {

    @Test func extractMetadataFromAllHongYiYeFixtures() throws {
        try LyraFixtureBatchTestHelper.runFixtureBatchTest(
            folder: "紅一葉",
            filePrefix: "紅一葉"
        )
    }
}
