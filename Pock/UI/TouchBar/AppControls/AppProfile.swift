//
//  AppProfile.swift
//  Pock
//
//  Per-app Touch Bar controls. Pure model code, kept free of Pock types so it can be unit tested.
//

import AppKit

internal struct KeyboardShortcut: Equatable {
	enum Key: Equatable {
		/// Resolved against the current keyboard layout when sent.
		case character(Character)
		/// Layout independent virtual key code.
		case code(UInt16)
	}
	let key: Key
	let modifiers: NSEvent.ModifierFlags

	private static let namedKeys: [String: UInt16] = [
		"return": 0x24, "tab": 0x30, "space": 0x31, "delete": 0x33, "esc": 0x35,
		"left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
		"f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60, "f6": 0x61,
		"f7": 0x62, "f8": 0x64, "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F
	]

	/// Parses `"cmd+shift+]"`, `"ctrl+tab"` or `"cmd+."`. The last component is the key.
	init?(_ spec: String) {
		var parts = spec.lowercased().components(separatedBy: "+")
		// A literal "+" key leaves an empty last component.
		if spec.hasSuffix("++") || spec == "+" {
			parts.removeLast(2)
			parts.append("+")
		}
		guard let last = parts.popLast(), !last.isEmpty else {
			return nil
		}
		var modifiers: NSEvent.ModifierFlags = []
		for part in parts {
			switch part {
			case "cmd", "command":
				modifiers.insert(.command)
			case "shift":
				modifiers.insert(.shift)
			case "opt", "option", "alt":
				modifiers.insert(.option)
			case "ctrl", "control":
				modifiers.insert(.control)
			default:
				return nil
			}
		}
		if let code = KeyboardShortcut.namedKeys[last] {
			key = .code(code)
		} else if last.count == 1, let character = last.first {
			key = .character(character)
		} else {
			return nil
		}
		self.modifiers = modifiers
	}
}

internal struct AppAction: Codable, Equatable {
	let title: String
	let symbol: String?
	let shortcut: String

	var keyboardShortcut: KeyboardShortcut? {
		return KeyboardShortcut(shortcut)
	}
}

internal struct AppProfile: Codable, Equatable {
	let id: String
	let name: String
	/// Bundle identifiers. A trailing `*` matches a prefix, e.g. `com.jetbrains.*`.
	let apps: [String]
	let actions: [AppAction]

	func matches(_ bundleIdentifier: String) -> Bool {
		return apps.contains { pattern in
			pattern.hasSuffix("*") ? bundleIdentifier.hasPrefix(String(pattern.dropLast())) : pattern == bundleIdentifier
		}
	}

	/// First profile that matches; custom profiles come before built-ins so they can override them.
	static func profile(for bundleIdentifier: String?, in profiles: [AppProfile], disabled: Set<String>) -> AppProfile? {
		guard let bundleIdentifier = bundleIdentifier else {
			return nil
		}
		return profiles.first { !disabled.contains($0.id) && $0.matches(bundleIdentifier) }
	}
}

extension AppProfile {
	private static func action(_ title: String, _ symbol: String?, _ shortcut: String) -> AppAction {
		return AppAction(title: title, symbol: symbol, shortcut: shortcut)
	}

	static let builtIn: [AppProfile] = [
		AppProfile(id: "browser", name: "Browsers", apps: [
			"com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.google.Chrome", "com.google.Chrome.*",
			"company.thebrowser.Browser", "org.mozilla.firefox", "com.microsoft.edgemac", "com.brave.Browser", "com.vivaldi.Vivaldi"
		], actions: [
			action("Back", "chevron.left", "cmd+["),
			action("Forward", "chevron.right", "cmd+]"),
			action("Reload", "arrow.clockwise", "cmd+r"),
			action("Address", "magnifyingglass", "cmd+l"),
			action("Previous tab", "arrow.left.to.line", "ctrl+shift+tab"),
			action("Next tab", "arrow.right.to.line", "ctrl+tab"),
			action("New tab", "plus", "cmd+t"),
			action("Close tab", "xmark", "cmd+w")
		]),
		AppProfile(id: "terminal", name: "Terminals", apps: [
			"com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable", "net.kovidgoyal.kitty"
		], actions: [
			action("Interrupt", "stop.circle", "ctrl+c"),
			action("Clear", "clear", "cmd+k"),
			action("Previous tab", "arrow.left.to.line", "cmd+shift+["),
			action("Next tab", "arrow.right.to.line", "cmd+shift+]"),
			action("New tab", "plus", "cmd+t"),
			action("Close tab", "xmark", "cmd+w")
		]),
		AppProfile(id: "code", name: "VS Code and Cursor", apps: [
			"com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92", "com.anysphere.*", "com.vscodium"
		], actions: [
			action("Quick Open", "doc.text.magnifyingglass", "cmd+p"),
			action("Commands", "command", "cmd+shift+p"),
			action("Search", "magnifyingglass", "cmd+shift+f"),
			action("Sidebar", "sidebar.left", "cmd+b"),
			action("Terminal", "terminal", "ctrl+`"),
			action("Back", "chevron.left", "ctrl+-"),
			action("Forward", "chevron.right", "ctrl+shift+-")
		]),
		AppProfile(id: "xcode", name: "Xcode", apps: ["com.apple.dt.Xcode"], actions: [
			action("Build", "hammer", "cmd+b"),
			action("Run", "play.fill", "cmd+r"),
			action("Stop", "stop.fill", "cmd+."),
			action("Test", "checkmark.diamond", "cmd+u"),
			action("Open Quickly", "doc.text.magnifyingglass", "cmd+shift+o"),
			action("Console", "rectangle.bottomthird.inset.filled", "cmd+shift+y")
		]),
		AppProfile(id: "finder", name: "Finder", apps: ["com.apple.finder"], actions: [
			action("Back", "chevron.left", "cmd+["),
			action("Forward", "chevron.right", "cmd+]"),
			action("Enclosing folder", "arrow.up", "cmd+up"),
			action("Go to folder", "folder", "cmd+shift+g"),
			action("New folder", "folder.badge.plus", "cmd+shift+n"),
			action("Quick Look", "eye", "space")
		]),
		AppProfile(id: "zoom", name: "Zoom", apps: ["us.zoom.xos"], actions: [
			action("Microphone", "mic.fill", "cmd+shift+a"),
			action("Camera", "video.fill", "cmd+shift+v"),
			action("Share screen", "rectangle.on.rectangle", "cmd+shift+s"),
			action("Chat", "message", "cmd+shift+h")
		]),
		AppProfile(id: "teams", name: "Microsoft Teams", apps: ["com.microsoft.teams2", "com.microsoft.teams"], actions: [
			action("Microphone", "mic.fill", "cmd+shift+m"),
			action("Camera", "video.fill", "cmd+shift+o"),
			action("Raise hand", "hand.raised", "cmd+shift+k")
		])
	]
}
