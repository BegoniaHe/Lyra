import Testing
@testable import Lyra
import Foundation

enum LyraFixtureBatchTestHelper {

    private static func emptyReport(folder: String, filePrefix: String) -> FixtureBatchReport {
        FixtureBatchReport(
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

    private static func discoverFixtureFiles(folder: String,
                                             filePrefix: String,
                                             supportedExtensions: Set<String>) -> [URL] {
        let fileManager = FileManager.default
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let lyraDirectory = testsDirectory.deletingLastPathComponent()
        let packageDirectory = lyraDirectory.deletingLastPathComponent()
        let workspaceDirectory = packageDirectory.deletingLastPathComponent().deletingLastPathComponent()

        let candidateDirectories: [URL] = [
            testsDirectory.appendingPathComponent(folder, isDirectory: true),
            testsDirectory.appendingPathComponent("TestAudio", isDirectory: true).appendingPathComponent(folder, isDirectory: true),
            packageDirectory.appendingPathComponent("TestAudio", isDirectory: true).appendingPathComponent(folder, isDirectory: true),
            workspaceDirectory.appendingPathComponent("TestAudio", isDirectory: true).appendingPathComponent(folder, isDirectory: true),
            workspaceDirectory.appendingPathComponent("TestAudio", isDirectory: true).appendingPathComponent("generated", isDirectory: true).appendingPathComponent(folder, isDirectory: true),
            workspaceDirectory.appendingPathComponent("TestAudio", isDirectory: true).appendingPathComponent("source", isDirectory: true)
        ]

        var foundFiles: [URL] = []
        var visitedPaths: Set<String> = []

        for directory in candidateDirectories {
            guard fileManager.fileExists(atPath: directory.path) else {
                continue
            }

            let standardizedPath = directory.standardizedFileURL.path
            if visitedPaths.contains(standardizedPath) {
                continue
            }
            visitedPaths.insert(standardizedPath)

            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            let matched = files.filter {
                let ext = $0.pathExtension.lowercased()
                guard !ext.isEmpty && supportedExtensions.contains(ext) else {
                    return false
                }

                guard !filePrefix.isEmpty else {
                    return true
                }
                return $0.deletingPathExtension().lastPathComponent.hasPrefix(filePrefix)
            }

            foundFiles.append(contentsOf: matched)
        }

        let unique = Dictionary(grouping: foundFiles, by: { $0.standardizedFileURL.path })
            .compactMap { $0.value.first }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return unique
    }

    enum MetadataField: String, CaseIterable, Codable {
        case title
        case artist
        case album
        case albumArtist
        case composer
        case comment
        case genre
        case year
        case track
        case trackNumber
        case totalTracks
        case discNumber
        case totalDiscs
        case bpm
        case compilation
        case releaseDate
        case originalReleaseDate
        case lyrics
        case sortTitle
        case sortArtist
        case sortAlbum
        case sortAlbumArtist
        case sortComposer
        case duration
        case bitrate
        case sampleRate
        case channels
        case bitDepth
        case codec
        case artworkData
        case artworkMimeType
        case isrc
        case label
        case encodedBy
        case encoderSettings
        case copyright
        case musicBrainzArtistId
        case musicBrainzAlbumId
        case musicBrainzTrackId
        case musicBrainzReleaseGroupId
        case replayGainTrack
        case replayGainAlbum
        case subtitle
        case grouping
        case movement
        case mood
        case language
        case key
    }

    struct FailedFile: Codable {
        let name: String
        let error: String
    }

    struct ExtractedTags: Codable {
        let title: String?
        let artist: String?
        let album: String?
        let albumArtist: String?
        let composer: String?
        let comment: String?
        let genre: String?
        let year: Int?
        let track: Int?
        let trackNumber: Int?
        let totalTracks: Int?
        let discNumber: Int?
        let totalDiscs: Int?
        let bpm: Int?
        let compilation: Bool?
        let releaseDate: String?
        let originalReleaseDate: String?
        let lyrics: String?
        let sortTitle: String?
        let sortArtist: String?
        let sortAlbum: String?
        let sortAlbumArtist: String?
        let sortComposer: String?
        let isrc: String?
        let label: String?
        let encodedBy: String?
        let encoderSettings: String?
        let copyright: String?
        let musicBrainzArtistId: String?
        let musicBrainzAlbumId: String?
        let musicBrainzTrackId: String?
        let musicBrainzReleaseGroupId: String?
        let replayGainTrack: String?
        let replayGainAlbum: String?
        let subtitle: String?
        let grouping: String?
        let movement: String?
        let mood: String?
        let language: String?
        let key: String?
    }

    struct ExtractedAudio: Codable {
        let duration: Int?
        let bitrate: Int?
        let sampleRate: Int?
        let channels: Int?
        let bitDepth: Int?
        let codec: String?
        let artworkDataSize: Int?
        let artworkMimeType: String?
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
        let supportedExtensions = Set(Lyra.supportedExtensions.map { $0.lowercased() })
        let allFiles = discoverFixtureFiles(folder: folder, filePrefix: filePrefix, supportedExtensions: supportedExtensions)
        guard !allFiles.isEmpty else {
            print("Skipping fixture batch \(folder): no matched test audio files found")
            return emptyReport(folder: folder, filePrefix: filePrefix)
        }

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
                    albumArtist: metadata.albumArtist,
                    composer: metadata.composer,
                    comment: metadata.comment,
                    genre: metadata.genre,
                    year: year,
                    track: track,
                    trackNumber: metadata.trackNumber.flatMap { Int(exactly: $0) },
                    totalTracks: metadata.totalTracks.flatMap { Int(exactly: $0) },
                    discNumber: metadata.discNumber.flatMap { Int(exactly: $0) },
                    totalDiscs: metadata.totalDiscs.flatMap { Int(exactly: $0) },
                    bpm: metadata.bpm.flatMap { Int(exactly: $0) },
                    compilation: metadata.compilation,
                    releaseDate: metadata.releaseDate,
                    originalReleaseDate: metadata.originalReleaseDate,
                    lyrics: metadata.lyrics,
                    sortTitle: metadata.sortTitle,
                    sortArtist: metadata.sortArtist,
                    sortAlbum: metadata.sortAlbum,
                    sortAlbumArtist: metadata.sortAlbumArtist,
                    sortComposer: metadata.sortComposer,
                    isrc: metadata.isrc,
                    label: metadata.label,
                    encodedBy: metadata.encodedBy,
                    encoderSettings: metadata.encoderSettings,
                    copyright: metadata.copyright,
                    musicBrainzArtistId: metadata.musicBrainzArtistId,
                    musicBrainzAlbumId: metadata.musicBrainzAlbumId,
                    musicBrainzTrackId: metadata.musicBrainzTrackId,
                    musicBrainzReleaseGroupId: metadata.musicBrainzReleaseGroupId,
                    replayGainTrack: metadata.replayGainTrack,
                    replayGainAlbum: metadata.replayGainAlbum,
                    subtitle: metadata.subtitle,
                    grouping: metadata.grouping,
                    movement: metadata.movement,
                    mood: metadata.mood,
                    language: metadata.language,
                    key: metadata.key
                )

                let audio = ExtractedAudio(
                    duration: metadata.duration,
                    bitrate: metadata.bitrate,
                    sampleRate: metadata.sampleRate,
                    channels: metadata.channels,
                    bitDepth: metadata.bitDepth,
                    codec: metadata.codec,
                    artworkDataSize: metadata.artworkData?.count,
                    artworkMimeType: metadata.artworkMimeType
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
                print("  tags: title=\(value(metadata.title)), artist=\(value(metadata.artist)), album=\(value(metadata.album)), albumArtist=\(value(metadata.albumArtist)), composer=\(value(metadata.composer)), year=\(value(metadata.year)), track=\(value(metadata.trackNumber ?? metadata.track)), disc=\(value(metadata.discNumber))")
                print("  audio: duration=\(value(metadata.duration))s, bitrate=\(value(metadata.bitrate))kbps, sampleRate=\(value(metadata.sampleRate))Hz, channels=\(value(metadata.channels)), bitDepth=\(value(metadata.bitDepth)), codec=\(value(metadata.codec)), artwork=\(value(metadata.artworkData?.count)) bytes")
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
        if let trackNumber = metadata.trackNumber {
            #expect(trackNumber > 0, "trackNumber must be > 0 in \(fileName)")
        }
        if let totalTracks = metadata.totalTracks {
            #expect(totalTracks > 0, "totalTracks must be > 0 in \(fileName)")
        }
        if let discNumber = metadata.discNumber {
            #expect(discNumber > 0, "discNumber must be > 0 in \(fileName)")
        }
        if let totalDiscs = metadata.totalDiscs {
            #expect(totalDiscs > 0, "totalDiscs must be > 0 in \(fileName)")
        }
        if let bpm = metadata.bpm {
            #expect(bpm > 0, "bpm must be > 0 in \(fileName)")
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
        if let bitDepth = metadata.bitDepth {
            #expect(bitDepth > 0, "bitDepth must be > 0 in \(fileName)")
        }
        if let artworkData = metadata.artworkData {
            #expect(!artworkData.isEmpty, "artworkData cannot be empty in \(fileName)")
        }
    }

    private static func recordCoverage(of metadata: AudioMetadata, into coverage: inout [MetadataField: Int]) {
        if metadata.title != nil { coverage[.title, default: 0] += 1 }
        if metadata.artist != nil { coverage[.artist, default: 0] += 1 }
        if metadata.album != nil { coverage[.album, default: 0] += 1 }
        if metadata.albumArtist != nil { coverage[.albumArtist, default: 0] += 1 }
        if metadata.composer != nil { coverage[.composer, default: 0] += 1 }
        if metadata.comment != nil { coverage[.comment, default: 0] += 1 }
        if metadata.genre != nil { coverage[.genre, default: 0] += 1 }
        if metadata.year != nil { coverage[.year, default: 0] += 1 }
        if metadata.track != nil { coverage[.track, default: 0] += 1 }
        if metadata.trackNumber != nil { coverage[.trackNumber, default: 0] += 1 }
        if metadata.totalTracks != nil { coverage[.totalTracks, default: 0] += 1 }
        if metadata.discNumber != nil { coverage[.discNumber, default: 0] += 1 }
        if metadata.totalDiscs != nil { coverage[.totalDiscs, default: 0] += 1 }
        if metadata.bpm != nil { coverage[.bpm, default: 0] += 1 }
        if metadata.compilation != nil { coverage[.compilation, default: 0] += 1 }
        if metadata.releaseDate != nil { coverage[.releaseDate, default: 0] += 1 }
        if metadata.originalReleaseDate != nil { coverage[.originalReleaseDate, default: 0] += 1 }
        if metadata.lyrics != nil { coverage[.lyrics, default: 0] += 1 }
        if metadata.sortTitle != nil { coverage[.sortTitle, default: 0] += 1 }
        if metadata.sortArtist != nil { coverage[.sortArtist, default: 0] += 1 }
        if metadata.sortAlbum != nil { coverage[.sortAlbum, default: 0] += 1 }
        if metadata.sortAlbumArtist != nil { coverage[.sortAlbumArtist, default: 0] += 1 }
        if metadata.sortComposer != nil { coverage[.sortComposer, default: 0] += 1 }
        if metadata.duration != nil { coverage[.duration, default: 0] += 1 }
        if metadata.bitrate != nil { coverage[.bitrate, default: 0] += 1 }
        if metadata.sampleRate != nil { coverage[.sampleRate, default: 0] += 1 }
        if metadata.channels != nil { coverage[.channels, default: 0] += 1 }
        if metadata.bitDepth != nil { coverage[.bitDepth, default: 0] += 1 }
        if metadata.codec != nil { coverage[.codec, default: 0] += 1 }
        if metadata.artworkData != nil { coverage[.artworkData, default: 0] += 1 }
        if metadata.artworkMimeType != nil { coverage[.artworkMimeType, default: 0] += 1 }
        if metadata.isrc != nil { coverage[.isrc, default: 0] += 1 }
        if metadata.label != nil { coverage[.label, default: 0] += 1 }
        if metadata.encodedBy != nil { coverage[.encodedBy, default: 0] += 1 }
        if metadata.encoderSettings != nil { coverage[.encoderSettings, default: 0] += 1 }
        if metadata.copyright != nil { coverage[.copyright, default: 0] += 1 }
        if metadata.musicBrainzArtistId != nil { coverage[.musicBrainzArtistId, default: 0] += 1 }
        if metadata.musicBrainzAlbumId != nil { coverage[.musicBrainzAlbumId, default: 0] += 1 }
        if metadata.musicBrainzTrackId != nil { coverage[.musicBrainzTrackId, default: 0] += 1 }
        if metadata.musicBrainzReleaseGroupId != nil { coverage[.musicBrainzReleaseGroupId, default: 0] += 1 }
        if metadata.replayGainTrack != nil { coverage[.replayGainTrack, default: 0] += 1 }
        if metadata.replayGainAlbum != nil { coverage[.replayGainAlbum, default: 0] += 1 }
        if metadata.subtitle != nil { coverage[.subtitle, default: 0] += 1 }
        if metadata.grouping != nil { coverage[.grouping, default: 0] += 1 }
        if metadata.movement != nil { coverage[.movement, default: 0] += 1 }
        if metadata.mood != nil { coverage[.mood, default: 0] += 1 }
        if metadata.language != nil { coverage[.language, default: 0] += 1 }
        if metadata.key != nil { coverage[.key, default: 0] += 1 }
    }
}
