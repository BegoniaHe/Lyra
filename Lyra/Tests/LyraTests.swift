import Testing
@testable import Lyra
import Foundation

enum LyraFixtureBatchTestHelper {

    enum MetadataField: String, CaseIterable, Codable {
        case title
        case artist
        case album
        case comment
        case genre
        case year
        case track
        case duration
        case bitrate
        case sampleRate
        case channels
    }

    struct FailedFile: Codable {
        let name: String
        let error: String
    }

    struct ExtractedTags: Codable {
        let title: String?
        let artist: String?
        let album: String?
        let comment: String?
        let genre: String?
        let year: Int?
        let track: Int?
    }

    struct ExtractedAudio: Codable {
        let duration: Int?
        let bitrate: Int?
        let sampleRate: Int?
        let channels: Int?
    }

    struct ExtractedFileMetadata: Codable {
        let fileName: String
        let tags: ExtractedTags?
        let audio: ExtractedAudio?
        let error: String?
    }

    struct FixtureBatchReport: Codable {
        let folder: String
        let filePrefix: String
        let generatedAt: String
        let totalFiles: Int
        let extractedMetadata: [ExtractedFileMetadata]
        let metadataFieldCoverage: [String: Int]
        let successfulFiles: [String]
        let failedFiles: [FailedFile]
        let filesMissingCoreTags: [String]
        let filesMissingAudioProperties: [String]
    }

    @discardableResult
    static func runFixtureBatchTest(folder: String, filePrefix: String) throws -> FixtureBatchReport {
        guard let resourceRoot = Bundle.module.resourceURL else {
            Issue.record("Test bundle resource root is missing")
            return FixtureBatchReport(
                folder: folder,
                filePrefix: filePrefix,
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                totalFiles: 0,
                extractedMetadata: [],
                metadataFieldCoverage: Dictionary(uniqueKeysWithValues: MetadataField.allCases.map { ($0.rawValue, 0) }),
                successfulFiles: [],
                failedFiles: [],
                filesMissingCoreTags: [],
                filesMissingAudioProperties: []
            )
        }

        let fileManager = FileManager.default
        let folderURLUnderModule = resourceRoot.appendingPathComponent(folder, isDirectory: true)
        let folderURLUnderTestAudio = resourceRoot
            .appendingPathComponent("TestAudio", isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)

        let searchDirectory: URL
        if fileManager.fileExists(atPath: folderURLUnderModule.path) {
            searchDirectory = folderURLUnderModule
        } else if fileManager.fileExists(atPath: folderURLUnderTestAudio.path) {
            searchDirectory = folderURLUnderTestAudio
        } else {
            searchDirectory = resourceRoot
        }

        let supportedExtensions = Set(Lyra.supportedExtensions.map { $0.lowercased() })

        let allFiles = try fileManager.contentsOfDirectory(
            at: searchDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter {
            let ext = $0.pathExtension.lowercased()
            return !ext.isEmpty && supportedExtensions.contains(ext)
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        #expect(!allFiles.isEmpty)

        var successfulFiles: [String] = []
        var failedFiles: [(name: String, error: String)] = []
        var filesMissingCoreTags: [String] = []
        var filesMissingAudioProperties: [String] = []
        var extractedMetadata: [ExtractedFileMetadata] = []
        var metadataFieldCoverage: [MetadataField: Int] = Dictionary(uniqueKeysWithValues: MetadataField.allCases.map { ($0, 0) })

        func value<T>(_ value: T?) -> String {
            guard let value else { return "nil" }
            return String(describing: value)
        }

        for fileURL in allFiles {
            do {
                let metadata = try Lyra.read(from: fileURL)
                successfulFiles.append(fileURL.lastPathComponent)

                let year: Int? = metadata.year.flatMap { Int(exactly: $0) }
                let track: Int? = metadata.track.flatMap { Int(exactly: $0) }

                let tags = ExtractedTags(
                    title: metadata.title,
                    artist: metadata.artist,
                    album: metadata.album,
                    comment: metadata.comment,
                    genre: metadata.genre,
                    year: year,
                    track: track
                )

                let audio = ExtractedAudio(
                    duration: metadata.duration,
                    bitrate: metadata.bitrate,
                    sampleRate: metadata.sampleRate,
                    channels: metadata.channels
                )

                validateSupportedMetadata(metadata, for: fileURL.lastPathComponent)
                recordCoverage(of: metadata, into: &metadataFieldCoverage)

                extractedMetadata.append(
                    ExtractedFileMetadata(
                        fileName: fileURL.lastPathComponent,
                        tags: tags,
                        audio: audio,
                        error: nil
                    )
                )

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
                extractedMetadata.append(
                    ExtractedFileMetadata(
                        fileName: fileURL.lastPathComponent,
                        tags: nil,
                        audio: nil,
                        error: String(describing: error)
                    )
                )
                print("\(fileURL.lastPathComponent) -> \(error)")
            }
        }

        #expect(!successfulFiles.isEmpty)
        print("\n=== Lyra metadata extraction summary (\(folder)) ===")
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

        #expect(metadataFieldCoverage.keys.count == MetadataField.allCases.count)

        print("\n=== Metadata field coverage ===")
        for field in MetadataField.allCases {
            let count = metadataFieldCoverage[field, default: 0]
            print("- \(field.rawValue): \(count)")
        }

        let report = FixtureBatchReport(
            folder: folder,
            filePrefix: filePrefix,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            totalFiles: allFiles.count,
            extractedMetadata: extractedMetadata,
            metadataFieldCoverage: Dictionary(uniqueKeysWithValues: metadataFieldCoverage.map { ($0.key.rawValue, $0.value) }),
            successfulFiles: successfulFiles,
            failedFiles: failedFiles.map { FailedFile(name: $0.name, error: $0.error) },
            filesMissingCoreTags: filesMissingCoreTags,
            filesMissingAudioProperties: filesMissingAudioProperties
        )

        try writeReportJSON(report, to: outputJSONURL(for: folder))

        return report
    }

    static func writeReportJSON(_ report: FixtureBatchReport, to outputURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: outputURL, options: [.atomic])
    }

    private static func outputJSONURL(for folder: String) -> URL {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileNameByFolder: [String: String] = [
            "7Years": "LyraTests+7Years.json",
            "紅一葉": "LyraTests+HongYiYe.json"
        ]
        let outputFileName = fileNameByFolder[folder] ?? "LyraTests+\(folder).json"
        return testsDirectory.appendingPathComponent(outputFileName, isDirectory: false)
    }

    private static func validateSupportedMetadata(_ metadata: AudioMetadata, for fileName: String) {
        func notBlank(_ value: String?) -> Bool {
            guard let value else { return true }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        #expect(notBlank(metadata.title), "title is blank in \(fileName)")
        #expect(notBlank(metadata.artist), "artist is blank in \(fileName)")
        #expect(notBlank(metadata.album), "album is blank in \(fileName)")
        #expect(notBlank(metadata.comment), "comment is blank in \(fileName)")
        #expect(notBlank(metadata.genre), "genre is blank in \(fileName)")

        if let year = metadata.year {
            #expect(year > 0, "year must be > 0 in \(fileName)")
        }
        if let track = metadata.track {
            #expect(track > 0, "track must be > 0 in \(fileName)")
        }
        if let duration = metadata.duration {
            #expect(duration >= 0, "duration must be >= 0 in \(fileName)")
        }
        if let bitrate = metadata.bitrate {
            #expect(bitrate >= 0, "bitrate must be >= 0 in \(fileName)")
        }
        if let sampleRate = metadata.sampleRate {
            #expect(sampleRate > 0, "sampleRate must be > 0 in \(fileName)")
        }
        if let channels = metadata.channels {
            #expect(channels > 0, "channels must be > 0 in \(fileName)")
        }
    }

    private static func recordCoverage(of metadata: AudioMetadata, into coverage: inout [MetadataField: Int]) {
        if metadata.title != nil { coverage[.title, default: 0] += 1 }
        if metadata.artist != nil { coverage[.artist, default: 0] += 1 }
        if metadata.album != nil { coverage[.album, default: 0] += 1 }
        if metadata.comment != nil { coverage[.comment, default: 0] += 1 }
        if metadata.genre != nil { coverage[.genre, default: 0] += 1 }
        if metadata.year != nil { coverage[.year, default: 0] += 1 }
        if metadata.track != nil { coverage[.track, default: 0] += 1 }
        if metadata.duration != nil { coverage[.duration, default: 0] += 1 }
        if metadata.bitrate != nil { coverage[.bitrate, default: 0] += 1 }
        if metadata.sampleRate != nil { coverage[.sampleRate, default: 0] += 1 }
        if metadata.channels != nil { coverage[.channels, default: 0] += 1 }
    }
}
