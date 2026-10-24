//
//  BuiltInWidgets.swift
//  Pock
//
//  Items compiled into Pock that replace the vendored default widget bundles.
//

import AppKit

internal enum BuiltInWidgets {

	static let identifiers: [NSTouchBarItem.Identifier] = [.appControls, .controls]

	/// Default widget bundles replaced by a built-in item.
	static let replacements: [String: NSTouchBarItem.Identifier] = [
		"com.pigigaldi.pock.ControlCenter": .controls
	]

	/// Bundle file names removed from the widgets folder once replaced.
	static let retiredWidgetBundles = ["ControlCenter.pock"]

	static func makeItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
		switch identifier {
		case .appControls:
			return AppControlsTouchBarItem(identifier: identifier)
		case .controls:
			return ControlsTouchBarItem(identifier: identifier)
		default:
			return nil
		}
	}

	/// Swaps replaced widgets for their built-in items in the saved layout, keeping their position.
	static func migrateSavedLayout() {
		let defaults = UserDefaults.standard
		let configKey = "NSTouchBarConfig: \(NSTouchBar.CustomizationIdentifier.pockTouchBarController)"
		guard var config = defaults.dictionary(forKey: configKey),
			  let items = config["CurrentItems"] as? [String] else {
			return
		}
		var migrated: [String] = []
		for item in items {
			let replacement = replacements[item]?.rawValue ?? item
			if !migrated.contains(replacement) || replacement == NSTouchBarItem.Identifier.flexibleSpace.rawValue {
				migrated.append(replacement)
			}
		}
		guard migrated != items else {
			return
		}
		config["CurrentItems"] = migrated
		defaults.set(config, forKey: configKey)
	}

	/// Removes installed copies of widgets that are now built in, so they are not loaded twice.
	static func removeRetiredWidgetBundles() {
		let folder = FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent("Library/Application Support/Pock/Widgets")
		for name in retiredWidgetBundles {
			let url = folder.appendingPathComponent(name)
			if FileManager.default.fileExists(atPath: url.path) {
				do {
					try FileManager.default.removeItem(at: url)
					Roger.info("[BuiltInWidgets] Removed retired widget \(name)")
				} catch {
					Roger.error("[BuiltInWidgets] Could not remove \(name): \(error)")
				}
			}
		}
	}
}
