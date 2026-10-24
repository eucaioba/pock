import Foundation

@main struct MediaSessionTests {
    static func main() throws {
        func snapshot(_ source: MediaSource, _ key: String, _ playing: Bool) -> MediaSnapshot {
            MediaSnapshot(source: source, key: key, title: "Track", artist: "Artist", album: "", playing: playing,
                          position: 15, duration: 60, artwork: nil)
        }
        let spotify = snapshot(.spotify, "track", true)
        let safari = snapshot(.safari, "video", true)
        let paused = snapshot(.safari, "paused", false)
        precondition(MediaSelection.select([spotify, safari], preference: .automatic, current: nil, frontmost: "com.apple.Safari") == safari)
        precondition(MediaSelection.select([spotify, safari], preference: .automatic, current: spotify, frontmost: nil) == spotify)
        precondition(MediaSelection.select([spotify, paused, safari], preference: .safari, current: nil, frontmost: nil) == safari)
        precondition(MediaSelection.select([spotify], preference: .safari, current: nil, frontmost: nil) == nil)
        precondition(MediaSelection.select([paused], preference: .automatic, current: nil, frontmost: nil) == paused)
        precondition(MediaSnapshot.clamped(.nan, duration: 10) == 0)
        precondition(MediaSnapshot.clamped(-2, duration: 10) == 0)
        precondition(MediaSnapshot.clamped(20, duration: 10) == 10)
        let decoded = try JSONDecoder().decode(MediaPoll.self, from: Data(#"{"sessions":[],"errors":[{"source":"safari","code":-1743,"message":"Denied"}]}"#.utf8))
        precondition(decoded.errors.first?.code == -1743)
        print("PASS media source selection, pinning, seeking bounds and permission errors")
    }
}
