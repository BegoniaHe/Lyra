import Testing
@testable import Lyra

struct Lyra7YearsTests {

    @Test func extractMetadataFromAll7YearsFixtures() throws {
        try LyraFixtureBatchTestHelper.runFixtureBatchTest(
            folder: "7Years",
            filePrefix: "Conor_Maynard_-_7_Years"
        )
    }
}
