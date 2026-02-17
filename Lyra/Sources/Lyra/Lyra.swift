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
            albumArtist: dict["albumArtist"] as? String,
            composer: dict["composer"] as? String,
            comment: dict["comment"] as? String,
            genre: dict["genre"] as? String,
            year: dict["year"] as? UInt,
            track: dict["track"] as? UInt,
            trackNumber: dict["trackNumber"] as? UInt,
            totalTracks: dict["totalTracks"] as? UInt,
            discNumber: dict["discNumber"] as? UInt,
            totalDiscs: dict["totalDiscs"] as? UInt,
            bpm: dict["bpm"] as? UInt,
            compilation: dict["compilation"] as? Bool,
            releaseDate: dict["releaseDate"] as? String,
            originalReleaseDate: dict["originalReleaseDate"] as? String,
            lyrics: dict["lyrics"] as? String,
            sortTitle: dict["sortTitle"] as? String,
            sortArtist: dict["sortArtist"] as? String,
            sortAlbum: dict["sortAlbum"] as? String,
            sortAlbumArtist: dict["sortAlbumArtist"] as? String,
            sortComposer: dict["sortComposer"] as? String,
            duration: dict["duration"] as? Int,
            bitrate: dict["bitrate"] as? Int,
            sampleRate: dict["sampleRate"] as? Int,
            channels: dict["channels"] as? Int,
            bitDepth: dict["bitDepth"] as? Int,
            codec: dict["codec"] as? String,
            artworkData: dict["artworkData"] as? Data,
            artworkMimeType: dict["artworkMimeType"] as? String,
            isrc: dict["isrc"] as? String,
            label: dict["label"] as? String,
            encodedBy: dict["encodedBy"] as? String,
            encoderSettings: dict["encoderSettings"] as? String,
            copyright: dict["copyright"] as? String,
            musicBrainzArtistId: dict["musicBrainzArtistId"] as? String,
            musicBrainzAlbumId: dict["musicBrainzAlbumId"] as? String,
            musicBrainzTrackId: dict["musicBrainzTrackId"] as? String,
            musicBrainzReleaseGroupId: dict["musicBrainzReleaseGroupId"] as? String,
            replayGainTrack: dict["replayGainTrack"] as? String,
            replayGainAlbum: dict["replayGainAlbum"] as? String,
            subtitle: dict["subtitle"] as? String,
            grouping: dict["grouping"] as? String,
            movement: dict["movement"] as? String,
            mood: dict["mood"] as? String,
            language: dict["language"] as? String,
            key: dict["key"] as? String
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
        if let albumArtist = metadata.albumArtist { dict["albumArtist"] = albumArtist }
        if let composer = metadata.composer { dict["composer"] = composer }
        if let track = metadata.trackNumber ?? metadata.track { dict["track"] = track }
        if let totalTracks = metadata.totalTracks { dict["totalTracks"] = totalTracks }
        if let discNumber = metadata.discNumber { dict["discNumber"] = discNumber }
        if let totalDiscs = metadata.totalDiscs { dict["totalDiscs"] = totalDiscs }
        if let bpm = metadata.bpm { dict["bpm"] = bpm }
        if let compilation = metadata.compilation { dict["compilation"] = compilation }
        if let releaseDate = metadata.releaseDate { dict["releaseDate"] = releaseDate }
        if let originalReleaseDate = metadata.originalReleaseDate { dict["originalReleaseDate"] = originalReleaseDate }
        if let lyrics = metadata.lyrics { dict["lyrics"] = lyrics }
        if let sortTitle = metadata.sortTitle { dict["sortTitle"] = sortTitle }
        if let sortArtist = metadata.sortArtist { dict["sortArtist"] = sortArtist }
        if let sortAlbum = metadata.sortAlbum { dict["sortAlbum"] = sortAlbum }
        if let sortAlbumArtist = metadata.sortAlbumArtist { dict["sortAlbumArtist"] = sortAlbumArtist }
        if let sortComposer = metadata.sortComposer { dict["sortComposer"] = sortComposer }
        if let isrc = metadata.isrc { dict["isrc"] = isrc }
        if let label = metadata.label { dict["label"] = label }
        if let encodedBy = metadata.encodedBy { dict["encodedBy"] = encodedBy }
        if let encoderSettings = metadata.encoderSettings { dict["encoderSettings"] = encoderSettings }
        if let copyright = metadata.copyright { dict["copyright"] = copyright }
        if let musicBrainzArtistId = metadata.musicBrainzArtistId { dict["musicBrainzArtistId"] = musicBrainzArtistId }
        if let musicBrainzAlbumId = metadata.musicBrainzAlbumId { dict["musicBrainzAlbumId"] = musicBrainzAlbumId }
        if let musicBrainzTrackId = metadata.musicBrainzTrackId { dict["musicBrainzTrackId"] = musicBrainzTrackId }
        if let musicBrainzReleaseGroupId = metadata.musicBrainzReleaseGroupId { dict["musicBrainzReleaseGroupId"] = musicBrainzReleaseGroupId }
        if let replayGainTrack = metadata.replayGainTrack { dict["replayGainTrack"] = replayGainTrack }
        if let replayGainAlbum = metadata.replayGainAlbum { dict["replayGainAlbum"] = replayGainAlbum }
        if let subtitle = metadata.subtitle { dict["subtitle"] = subtitle }
        if let grouping = metadata.grouping { dict["grouping"] = grouping }
        if let movement = metadata.movement { dict["movement"] = movement }
        if let mood = metadata.mood { dict["mood"] = mood }
        if let language = metadata.language { dict["language"] = language }
        if let key = metadata.key { dict["key"] = key }
        
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
