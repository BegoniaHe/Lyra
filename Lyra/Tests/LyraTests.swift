import Testing
@testable import Lyra
import Foundation

struct LyraTests {

    @Test func extractMetadataFromAllHongYiYeFixtures() throws {
        guard let testAudioRoot = Bundle.module.url(forResource: "TestAudio", withExtension: nil) else {
            Issue.record("TestAudio resource directory is missing")
            return
        }

        let testFileDirectory = testAudioRoot
            .appendingPathComponent("紅一葉", isDirectory: true)

        let allFiles = try FileManager.default.contentsOfDirectory(
            at: testFileDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasPrefix("紅一葉.") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        #expect(!allFiles.isEmpty)

        var successfulFiles: [String] = []
        var failedFiles: [(name: String, error: String)] = []
        var filesMissingCoreTags: [String] = []
        var filesMissingAudioProperties: [String] = []

        func value<T>(_ value: T?) -> String {
            guard let value else { return "nil" }
            return String(describing: value)
        }

        for fileURL in allFiles {
            do {
                let metadata = try Lyra.read(from: fileURL)
                successfulFiles.append(fileURL.lastPathComponent)

                if metadata.title == nil && metadata.artist == nil && metadata.album == nil {
                    filesMissingCoreTags.append(fileURL.lastPathComponent)
                }

                if metadata.duration == nil && metadata.bitrate == nil && metadata.sampleRate == nil && metadata.channels == nil {
                    filesMissingAudioProperties.append(fileURL.lastPathComponent)
                }

                print("\(fileURL.lastPathComponent)")
                print("  tags: title=\(value(metadata.title)), artist=\(value(metadata.artist)), album=\(value(metadata.album)), comment=\(value(metadata.comment)), genre=\(value(metadata.genre)), year=\(value(metadata.year)), track=\(value(metadata.track))")
                print("  audio: duration=\(value(metadata.duration))s, bitrate=\(value(metadata.bitrate))kbps, sampleRate=\(value(metadata.sampleRate))Hz, channels=\(value(metadata.channels))")
            } catch {
                failedFiles.append((fileURL.lastPathComponent, String(describing: error)))
                print("\(fileURL.lastPathComponent) -> \(error)")
            }
        }

        #expect(!successfulFiles.isEmpty)
        print("\n=== Lyra metadata extraction summary ===")
        print("Success: \(successfulFiles.count), Failed: \(failedFiles.count)")

        print("\n=== Detailed summary ===")
        print("Files missing core tags (title+artist+album all nil): \(filesMissingCoreTags.count)")
        print("Files missing audio properties (duration+bitrate+sampleRate+channels all nil): \(filesMissingAudioProperties.count)")

        if !filesMissingCoreTags.isEmpty {
            print("- Missing core tags: \(filesMissingCoreTags.joined(separator: ", "))")
        }
        if !filesMissingAudioProperties.isEmpty {
            print("- Missing audio properties: \(filesMissingAudioProperties.joined(separator: ", "))")
        }

        if !failedFiles.isEmpty {
            for failed in failedFiles {
                print("- \(failed.name): \(failed.error)")
            }
        }
    }

}
