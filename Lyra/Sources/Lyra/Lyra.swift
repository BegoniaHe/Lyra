import Foundation
import LyraBridge

public struct Lyra {
    
    /// Reads metadata from an audio file
    public static func read(from url: URL) throws -> AudioMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LyraError.fileNotFound
        }
        
        guard let dict = LyraBridge.readMetadata(fromFile: url.path) else {
            throw LyraError.readFailed
        }
        
        return AudioMetadata(
            title: dict["title"] as? String,
            artist: dict["artist"] as? String,
            album: dict["album"] as? String,
            comment: dict["comment"] as? String,
            genre: dict["genre"] as? String,
            year: dict["year"] as? UInt,
            track: dict["track"] as? UInt,
            duration: dict["duration"] as? Int,
            bitrate: dict["bitrate"] as? Int,
            sampleRate: dict["sampleRate"] as? Int,
            channels: dict["channels"] as? Int
        )
    }
    
    /// Writes metadata to an audio file
    public static func write(_ metadata: AudioMetadata, to url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LyraError.fileNotFound
        }
        
        var dict: [String: Any] = [:]
        if let title = metadata.title { dict["title"] = title }
        if let artist = metadata.artist { dict["artist"] = artist }
        if let album = metadata.album { dict["album"] = album }
        if let comment = metadata.comment { dict["comment"] = comment }
        if let genre = metadata.genre { dict["genre"] = genre }
        if let year = metadata.year { dict["year"] = year }
        if let track = metadata.track { dict["track"] = track }
        
        let success = LyraBridge.writeMetadata(dict, toFile: url.path)
        if !success {
            throw LyraError.writeFailed
        }
    }
    
    /// Returns a list of supported audio file extensions (e.g., ["mp3", "flac", "wav"])
    public static var supportedExtensions: [String] {
        LyraBridge.supportedFileExtensions() ?? []
    }
}
