//
//  BuiltInWidgets.swift
//  Pock
//
//  Items compiled into Pock that replace the vendored default widget bundles.
//

import AppKit

internal enum BuiltInWidgets {

	static let identifiers: [NSTouchBarItem.Identifier] = [.appControls, .controls, .status, .dock, .weather]

	/// Default widget bundles replaced by a built-in item.
	static let replacements: [String: NSTouchBarItem.Identifier] = [
		"com.pigigaldi.pock.ControlCenter": .controls,
		"com.pigigaldi.pock.Status": .status,
		"com.pigigaldi.pock.Dock": .dock,
		"com.pigigaldi.pock.Weather": .weather
	]

	/// Bundle file names removed from the widgets folder once replaced.
	static let retiredWidgetBundles = ["ControlCenter.pock", "Status.pock", "Dock.pock", "Weather.pock"]

	static func makeItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
		switch identifier {
		case .appControls:
			return AppControlsTouchBarItem(identifier: identifier)
		case .controls:
			return ControlsTouchBarItem(identifier: identifier)
		case .status:
			return StatusTouchBarItem(identifier: identifier)
		case .dock:
			return DockTouchBarItem(identifier: identifier)
		case .weather:
			return WeatherTouchBarItem(identifier: identifier)
		default:
			return nil
		}
	}

	/// Widest a palette preview grows, so wide items (the Dock) stay easy to drag.
	private static let maxPreviewWidth: CGFloat = 170

	/// Static snapshot of a live item for the customization palette, falling back to a labelled chip
	/// when the item has nothing to draw yet (no data, no profile, zero width).
	static func previewView(for item: NSTouchBarItem) -> NSView {
		let label = item.customizationLabel ?? "Item"
		if let live = (item as? NSCustomTouchBarItem)?.view {
			// The Touch Bar is always dark; a snapshot taken in the default appearance draws black text on black.
			let previousAppearance = live.appearance
			live.appearance = NSAppearance(named: .darkAqua)
			defer {
				live.appearance = previousAppearance
			}
			live.layoutSubtreeIfNeeded()
			let width = live.frame.width > 0 ? live.frame.width : live.fittingSize.width
			if width > 0, let image = NSImage(frame: NSRect(x: 0, y: 0, width: width, height: 30), view: live), !isBlank(image) {
				let preview = NSImageView(image: image)
				preview.imageScaling = .scaleProportionallyDown
				if width > maxPreviewWidth {
					preview.widthAnchor.constraint(equalToConstant: maxPreviewWidth).isActive = true
				}
				return preview
			}
		}
		return chip(label)
	}

	/// Widget bundles hand the palette a snapshot that is blank while they have nothing to show
	/// (e.g. Now Playing with no media), which leaves no way to find or drag them; swap in a chip.
	static func visiblePreview(_ view: NSView, label: String?) -> NSView {
		if let imageView = view as? NSImageView, let image = imageView.image, isBlank(image) {
			return chip(label ?? "Item")
		}
		return view
	}

	private static func chip(_ text: String) -> NSView {
		let label = NSTextField(labelWithString: text)
		label.font = .systemFont(ofSize: 11, weight: .semibold)
		label.textColor = .white
		let box = NSStackView(views: [label])
		box.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
		box.wantsLayer = true
		box.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
		box.layer?.cornerRadius = 6
		return box
	}

	/// True when a snapshot has no visible pixel.
	private static func isBlank(_ image: NSImage) -> Bool {
		guard let rep = image.representations.first as? NSBitmapImageRep else {
			return true
		}
		for y in 0..<rep.pixelsHigh {
			for x in 0..<rep.pixelsWide {
				if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.05 {
					return false
				}
			}
		}
		return true
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
