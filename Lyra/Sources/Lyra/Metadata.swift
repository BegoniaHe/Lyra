import Foundation

/// Represents the metadata of an audio file, including both core tags and audio properties.
public struct AudioMetadata {
    // MARK: - Core Tags
    public var title: String?
    public var artist: String?
    public var album: String?
    public var albumArtist: String?
    public var composer: String?
    public var comment: String?
    public var genre: String?
    public var year: UInt?
    public var track: UInt? // Backward compatible alias of trackNumber
    public var trackNumber: UInt?
    public var totalTracks: UInt?
    public var discNumber: UInt?
    public var totalDiscs: UInt?
    public var bpm: UInt?
    public var compilation: Bool?
    public var releaseDate: String?
    public var originalReleaseDate: String?
    public var lyrics: String?

    // MARK: - Sort Tags
    public var sortTitle: String?
    public var sortArtist: String?
    public var sortAlbum: String?
    public var sortAlbumArtist: String?
    public var sortComposer: String?
    
    // MARK: - Audio Properties
    public var duration: Int?      // seconds
    public var bitrate: Int?       // kbps
    public var sampleRate: Int?    // Hz
    public var channels: Int?
    public var bitDepth: Int?
    public var codec: String?

    // MARK: - Artwork
    public var artworkData: Data?
    public var artworkMimeType: String?

    // MARK: - Identifiers & Extended
    public var isrc: String?
    public var label: String?
    public var encodedBy: String?
    public var encoderSettings: String?
    public var copyright: String?

    public var musicBrainzArtistId: String?
    public var musicBrainzAlbumId: String?
    public var musicBrainzTrackId: String?
    public var musicBrainzReleaseGroupId: String?

    public var replayGainTrack: String?
    public var replayGainAlbum: String?

    public var subtitle: String?
    public var grouping: String?
    public var movement: String?
    public var mood: String?
    public var language: String?
    public var key: String?
    
    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumArtist: String? = nil,
        composer: String? = nil,
        comment: String? = nil,
        genre: String? = nil,
        year: UInt? = nil,
        track: UInt? = nil,
        trackNumber: UInt? = nil,
        totalTracks: UInt? = nil,
        discNumber: UInt? = nil,
        totalDiscs: UInt? = nil,
        bpm: UInt? = nil,
        compilation: Bool? = nil,
        releaseDate: String? = nil,
        originalReleaseDate: String? = nil,
        lyrics: String? = nil,
        sortTitle: String? = nil,
        sortArtist: String? = nil,
        sortAlbum: String? = nil,
        sortAlbumArtist: String? = nil,
        sortComposer: String? = nil,
        duration: Int? = nil,
        bitrate: Int? = nil,
        sampleRate: Int? = nil,
        channels: Int? = nil,
        bitDepth: Int? = nil,
        codec: String? = nil,
        artworkData: Data? = nil,
        artworkMimeType: String? = nil,
        isrc: String? = nil,
        label: String? = nil,
        encodedBy: String? = nil,
        encoderSettings: String? = nil,
        copyright: String? = nil,
        musicBrainzArtistId: String? = nil,
        musicBrainzAlbumId: String? = nil,
        musicBrainzTrackId: String? = nil,
        musicBrainzReleaseGroupId: String? = nil,
        replayGainTrack: String? = nil,
        replayGainAlbum: String? = nil,
        subtitle: String? = nil,
        grouping: String? = nil,
        movement: String? = nil,
        mood: String? = nil,
        language: String? = nil,
        key: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.composer = composer
        self.comment = comment
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber ?? track
        self.track = self.trackNumber
        self.totalTracks = totalTracks
        self.discNumber = discNumber
        self.totalDiscs = totalDiscs
        self.bpm = bpm
        self.compilation = compilation
        self.releaseDate = releaseDate
        self.originalReleaseDate = originalReleaseDate
        self.lyrics = lyrics
        self.sortTitle = sortTitle
        self.sortArtist = sortArtist
        self.sortAlbum = sortAlbum
        self.sortAlbumArtist = sortAlbumArtist
        self.sortComposer = sortComposer
        self.duration = duration
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitDepth = bitDepth
        self.codec = codec
        self.artworkData = artworkData
        self.artworkMimeType = artworkMimeType
        self.isrc = isrc
        self.label = label
        self.encodedBy = encodedBy
        self.encoderSettings = encoderSettings
        self.copyright = copyright
        self.musicBrainzArtistId = musicBrainzArtistId
        self.musicBrainzAlbumId = musicBrainzAlbumId
        self.musicBrainzTrackId = musicBrainzTrackId
        self.musicBrainzReleaseGroupId = musicBrainzReleaseGroupId
        self.replayGainTrack = replayGainTrack
        self.replayGainAlbum = replayGainAlbum
        self.subtitle = subtitle
        self.grouping = grouping
        self.movement = movement
        self.mood = mood
        self.language = language
        self.key = key
    }
}

public enum LyraError: Error {
    case fileNotFound
    case unsupportedFormat
    case readFailed
    case writeFailed
    case invalidMetadata
}
