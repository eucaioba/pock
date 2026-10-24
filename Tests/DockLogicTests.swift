import Foundation

@main struct DockLogicTests {
	static func main() {
		func tile(_ id: String, _ name: String) -> [String: Any] {
			["tile-data": ["bundle-identifier": id, "file-label": name]]
		}
		let domain: [String: Any] = [
			"persistent-apps": [tile("com.apple.Safari", "Safari"), tile("com.spotify.client", "Spotify"),
								tile("com.apple.finder", "Finder"), ["tile-data": ["file-label": "No identifier"]]],
			"persistent-others": [
				["tile-data": ["file-label": "Downloads", "file-data": ["_CFURLString": "file:///Users/me/Downloads/"]]],
				["tile-data": ["file-label": "Web", "file-data": ["_CFURLString": "https://example.com"]]]
			]
		]
		let pinned = DockLogic.pinnedApps(from: domain)
		precondition(pinned.map(\.bundleIdentifier) == ["com.apple.Safari", "com.spotify.client", "com.apple.finder"])
		precondition(pinned[0].name == "Safari")
		precondition(DockLogic.pinnedApps(from: nil).isEmpty)
		let folders = DockLogic.folders(from: domain)
		precondition(folders.count == 1 && folders[0].name == "Downloads" && folders[0].url.path == "/Users/me/Downloads")

		let running = [DockRunningEntry(bundleIdentifier: "com.apple.finder", name: "Finder", pid: 10),
					   DockRunningEntry(bundleIdentifier: "com.anysphere.sand", name: "Cursor", pid: 20),
					   DockRunningEntry(bundleIdentifier: "com.spotify.client", name: "Spotify", pid: 30)]
		let all = DockLogic.merge(pinned: pinned, running: running, hideFinder: false, onlyRunning: false)
		precondition(all.map(\.bundleIdentifier) == ["com.apple.finder", "com.apple.Safari", "com.spotify.client", "com.anysphere.sand"])
		precondition(all.map(\.isRunning) == [true, false, true, true])
		precondition(all.map(\.isPinned) == [true, true, true, false])

		let noFinder = DockLogic.merge(pinned: pinned, running: running, hideFinder: true, onlyRunning: false)
		precondition(noFinder.first?.bundleIdentifier == "com.apple.Safari" && !noFinder.contains { $0.bundleIdentifier == "com.apple.finder" })

		let onlyRunning = DockLogic.merge(pinned: pinned, running: running, hideFinder: false, onlyRunning: true)
		precondition(onlyRunning.map(\.bundleIdentifier) == ["com.apple.finder", "com.spotify.client", "com.anysphere.sand"])
		// Finder stays visible even if it is somehow not in the running list.
		precondition(DockLogic.merge(pinned: [], running: [], hideFinder: false, onlyRunning: true).map(\.bundleIdentifier) == ["com.apple.finder"])

		precondition(DockLogic.badgeText(nil) == nil && DockLogic.badgeText("  ") == nil)
		precondition(DockLogic.badgeText("3") == "3" && DockLogic.badgeText("99+") == "99+")
		precondition(DockLogic.badgeText("12345") == "12…")
		print("PASS Dock plist parsing, ordering, Finder and only-running options, badge text")
	}
}
