import Foundation

/// Represents the metadata of an audio file, including both core tags and audio properties.
public struct AudioMetadata {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var comment: String?
    public var genre: String?
    public var year: UInt?
    public var track: UInt?
    
    // audio properties
    public var duration: Int?      // seconds
    public var bitrate: Int?       // kbps
    public var sampleRate: Int?    // Hz
    public var channels: Int?
    
    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        comment: String? = nil,
        genre: String? = nil,
        year: UInt? = nil,
        track: UInt? = nil,
        duration: Int? = nil,
        bitrate: Int? = nil,
        sampleRate: Int? = nil,
        channels: Int? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.comment = comment
        self.genre = genre
        self.year = year
        self.track = track
        self.duration = duration
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.channels = channels
    }
}

public enum LyraError: Error {
    case fileNotFound
    case unsupportedFormat
    case readFailed
    case writeFailed
    case invalidMetadata
}
