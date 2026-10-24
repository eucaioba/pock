//
//  DockLogic.swift
//  Pock
//
//  Pure helpers for the Dock item, kept free of AppKit so they can be unit tested.
//

import Foundation

internal struct DockApp: Equatable {
	let bundleIdentifier: String
	var name: String
	/// Process identifier of the running instance, 0 when the app is not running.
	var pid: Int32
	var isPinned: Bool

	var isRunning: Bool {
		return pid != 0
	}
}

internal struct DockPinnedEntry: Equatable {
	let bundleIdentifier: String
	let name: String
}

internal struct DockFolderEntry: Equatable {
	let name: String
	let url: URL
}

internal struct DockRunningEntry: Equatable {
	let bundleIdentifier: String
	let name: String
	let pid: Int32
}

internal enum DockLogic {

	static let finderIdentifier = "com.apple.finder"

	/// Apps pinned in the system Dock, in order (`persistent-apps`).
	static func pinnedApps(from domain: [String: Any]?) -> [DockPinnedEntry] {
		let tiles = domain?["persistent-apps"] as? [[String: Any]] ?? []
		return tiles.compactMap { tile in
			guard let data = tile["tile-data"] as? [String: Any],
				  let identifier = data["bundle-identifier"] as? String, !identifier.isEmpty else {
				return nil
			}
			return DockPinnedEntry(bundleIdentifier: identifier, name: data["file-label"] as? String ?? identifier)
		}
	}

	/// Folders and files kept on the right side of the system Dock (`persistent-others`).
	static func folders(from domain: [String: Any]?) -> [DockFolderEntry] {
		let tiles = domain?["persistent-others"] as? [[String: Any]] ?? []
		return tiles.compactMap { tile in
			guard let data = tile["tile-data"] as? [String: Any],
				  let file = data["file-data"] as? [String: Any],
				  let string = file["_CFURLString"] as? String,
				  let url = URL(string: string), url.isFileURL else {
				return nil
			}
			let name = data["file-label"] as? String ?? url.lastPathComponent
			return DockFolderEntry(name: name, url: url)
		}
	}

	/// Finder first, then pinned apps in Dock order, then other running apps in the order given.
	static func merge(pinned: [DockPinnedEntry], running: [DockRunningEntry],
					  hideFinder: Bool, onlyRunning: Bool) -> [DockApp] {
		var result: [DockApp] = []
		func pid(of identifier: String) -> Int32 {
			return running.first(where: { $0.bundleIdentifier == identifier })?.pid ?? 0
		}
		func append(_ identifier: String, name: String, pinned: Bool) {
			guard !result.contains(where: { $0.bundleIdentifier == identifier }) else {
				return
			}
			let pid = pid(of: identifier)
			guard pid != 0 || !onlyRunning || identifier == finderIdentifier else {
				return
			}
			result.append(DockApp(bundleIdentifier: identifier, name: name, pid: pid, isPinned: pinned))
		}
		if !hideFinder {
			append(finderIdentifier, name: "Finder", pinned: true)
		}
		for entry in pinned where entry.bundleIdentifier != finderIdentifier {
			append(entry.bundleIdentifier, name: entry.name, pinned: true)
		}
		for entry in running where entry.bundleIdentifier != finderIdentifier {
			append(entry.bundleIdentifier, name: entry.name, pinned: false)
		}
		return result
	}

	/// Dock badge text to show: Dock reports "•" for plain notifications and a number or text otherwise.
	static func badgeText(_ raw: String?) -> String? {
		guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
			return nil
		}
		return text.count > 3 ? String(text.prefix(2)) + "…" : text
	}
}
