//
//  AppControlsTouchBarItem.swift
//  Pock
//
//  Built-in Touch Bar item whose buttons follow the frontmost app.
//

import AppKit

extension NSTouchBarItem.Identifier {
	static let appControls = NSTouchBarItem.Identifier("com.pigigaldi.pock.AppControls")
}

extension NSNotification.Name {
	static let appProfilesDidChange = NSNotification.Name("appProfilesDidChange")
}

internal final class AppControlsTouchBarItem: NSCustomTouchBarItem {

	/// Optional user profiles, matched before the built-in ones.
	static var customProfilesURL: URL {
		return FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent("Library/Application Support/Pock/AppProfiles.json")
	}

	static var customProfiles: [AppProfile] {
		guard let data = try? Data(contentsOf: customProfilesURL) else {
			return []
		}
		do {
			return try JSONDecoder().decode([AppProfile].self, from: data)
		} catch {
			Roger.error("[AppControls] Invalid \(customProfilesURL.path): \(error)")
			return []
		}
	}

	static var allProfiles: [AppProfile] {
		return customProfiles + AppProfile.builtIn
	}

	static var disabledProfiles: Set<String> {
		get {
			return Set(UserDefaults.standard.stringArray(forKey: "disabledAppProfiles") ?? [])
		}
		set {
			UserDefaults.standard.set(newValue.sorted(), forKey: "disabledAppProfiles")
			NotificationCenter.default.post(name: .appProfilesDidChange, object: nil)
		}
	}

	/// Adds App Controls once to a layout the user saved before the item existed, right after the Dock.
	static func insertIntoSavedLayoutIfNeeded() {
		let defaults = UserDefaults.standard
		let migrationKey = "didInsertAppControlsIntoLayout"
		let configKey = "NSTouchBarConfig: \(NSTouchBar.CustomizationIdentifier.pockTouchBarController)"
		guard !defaults.bool(forKey: migrationKey) else {
			return
		}
		defaults.set(true, forKey: migrationKey)
		guard var config = defaults.dictionary(forKey: configKey),
			  var items = config["CurrentItems"] as? [String],
			  !items.contains(NSTouchBarItem.Identifier.appControls.rawValue) else {
			return
		}
		let index = items.firstIndex(of: "com.pigigaldi.pock.Dock").map { $0 + 1 } ?? 0
		items.insert(NSTouchBarItem.Identifier.appControls.rawValue, at: index)
		config["CurrentItems"] = items
		defaults.set(config, forKey: configKey)
	}

	private let stackView = NSStackView()
	private var profiles: [AppProfile] = []
	private var actions: [AppAction] = []
	private weak var targetApplication: NSRunningApplication?

	override init(identifier: NSTouchBarItem.Identifier) {
		super.init(identifier: identifier)
		customizationLabel = "App Controls"
		// When the bar runs out of room, drop these buttons before widgets like Status.
		visibilityPriority = .low
		stackView.orientation = .horizontal
		stackView.spacing = 4
		view = stackView
		reloadProfiles()
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationDidActivate(_:)),
														  name: NSWorkspace.didActivateApplicationNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(reloadProfiles), name: .appProfilesDidChange, object: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		NSWorkspace.shared.notificationCenter.removeObserver(self)
		NotificationCenter.default.removeObserver(self)
	}

	@objc private func reloadProfiles() {
		profiles = AppControlsTouchBarItem.allProfiles
		update(for: NSWorkspace.shared.frontmostApplication)
	}

	@objc private func applicationDidActivate(_ notification: Notification) {
		update(for: notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
	}

	private func update(for app: NSRunningApplication?) {
		// Pock's own windows (Preferences, Widgets Manager) keep the previous app's controls.
		if app?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
			return
		}
		targetApplication = app
		let profile = AppProfile.profile(for: app?.bundleIdentifier, in: profiles, disabled: AppControlsTouchBarItem.disabledProfiles)
		let newActions = profile?.actions ?? []
		guard newActions != actions || stackView.arrangedSubviews.count != newActions.count else {
			return
		}
		actions = newActions
		stackView.arrangedSubviews.forEach {
			stackView.removeArrangedSubview($0)
			$0.removeFromSuperview()
		}
		for (index, action) in actions.enumerated() {
			stackView.addArrangedSubview(button(for: action, tag: index))
		}
	}

	private func button(for action: AppAction, tag: Int) -> NSButton {
		let button: NSButton
		if #available(macOS 11.0, *), let symbol = action.symbol,
		   let image = NSImage(systemSymbolName: symbol, accessibilityDescription: action.title) {
			button = NSButton(image: image, target: self, action: #selector(performAction(_:)))
			button.widthAnchor.constraint(equalToConstant: 34).isActive = true
		} else {
			button = NSButton(title: action.title, target: self, action: #selector(performAction(_:)))
		}
		button.tag = tag
		button.toolTip = "\(action.title) (\(action.shortcut))"
		button.setAccessibilityLabel(action.title)
		return button
	}

	@objc private func performAction(_ sender: NSButton) {
		guard actions.indices.contains(sender.tag),
			  let shortcut = actions[sender.tag].keyboardShortcut,
			  let app = targetApplication ?? NSWorkspace.shared.frontmostApplication else {
			return
		}
		if !KeyboardShortcutSender.send(shortcut, to: app) {
			NSSound.beep()
		}
	}
}
