import Foundation

enum MediaSource: String, CaseIterable, Codable {
    case automatic, spotify, safari, music

    var title: String {
        switch self {
        case .automatic: return "Automático"
        case .spotify: return "Spotify"
        case .safari: return "YouTube / Safari"
        case .music: return "Apple Music"
        }
    }
    var bundleIdentifier: String? {
        switch self {
        case .automatic: return nil
        case .spotify: return "com.spotify.client"
        case .safari: return "com.apple.Safari"
        case .music: return "com.apple.Music"
        }
    }
}

struct MediaSnapshot: Decodable, Equatable {
    let source: MediaSource
    let key: String
    let title: String
    let artist: String
    let album: String
    let playing: Bool
    let position: Double
    let duration: Double
    let artwork: String?
    var observedAt = Date()

    private enum CodingKeys: String, CodingKey {
        case source, key, title, artist, album, playing, position, duration, artwork
    }
    var identity: String { source.rawValue + ":" + key }
    var displayPosition: Double {
        let elapsed = playing ? max(0, Date().timeIntervalSince(observedAt)) : 0
        return Self.clamped(position + elapsed, duration: duration)
    }
    static func clamped(_ value: Double, duration: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, duration.isFinite && duration > 0 ? min(value, duration) : value)
    }
}

struct MediaPoll: Decodable {
    struct Failure: Decodable { let source: MediaSource; let code: Int; let message: String }
    let sessions: [MediaSnapshot]
    let errors: [Failure]
}

enum MediaSelection {
    static func select(_ sessions: [MediaSnapshot], preference: MediaSource,
                       current: MediaSnapshot?, frontmost: String?) -> MediaSnapshot? {
        let available = sessions.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let pool = preference == .automatic ? available : available.filter { $0.source == preference }
        let playing = pool.filter { $0.playing }
        if let focused = playing.first(where: { $0.source.bundleIdentifier == frontmost }) { return focused }
        if let same = playing.first(where: { $0.identity == current?.identity }) { return same }
        if let first = playing.first { return first }
        return pool.first(where: { $0.identity == current?.identity }) ?? pool.first
    }
}
