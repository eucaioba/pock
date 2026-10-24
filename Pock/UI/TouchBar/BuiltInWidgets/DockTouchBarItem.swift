//
//  DockTouchBarItem.swift
//  Pock
//
//  Built-in replacement for the Dock widget: pinned and running apps with running indicators and
//  notification badges, plus the system Dock's folders and the Trash. Reads the system Dock's own
//  preferences, so there is nothing to configure beyond a few display options.
//

import AppKit

extension NSTouchBarItem.Identifier {
	static let dock = NSTouchBarItem.Identifier("com.pigigaldi.pock.DockItem")
}

extension NSNotification.Name {
	static let dockDidChange = NSNotification.Name("dockDidChange")
}

/// Badge labels shown on Dock icons, read from the system Dock through Accessibility.
internal enum DockBadges {
	static func read() -> [String: String] {
		guard AXIsProcessTrusted(),
			  let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
			return [:]
		}
		let application = AXUIElementCreateApplication(dock.processIdentifier)
		guard let list = children(of: application).first(where: { string("AXRole", of: $0) == "AXList" }) else {
			return [:]
		}
		var badges: [String: String] = [:]
		for item in children(of: list) {
			if let title = string(kAXTitleAttribute, of: item), let label = string("AXStatusLabel", of: item) {
				badges[title] = label
			}
		}
		return badges
	}

	private static func children(of element: AXUIElement) -> [AXUIElement] {
		var value: CFTypeRef?
		guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else {
			return []
		}
		return value as? [AXUIElement] ?? []
	}

	private static func string(_ attribute: String, of element: AXUIElement) -> String? {
		var value: CFTypeRef?
		guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
			return nil
		}
		return value as? String
	}
}

private final class DockItemView: NSScrubberItemView {
	static let size = NSSize(width: 40, height: 30)
	private let imageView = NSImageView()
	private let dot = NSView()
	private let badge = NSTextField(labelWithString: "")
	private let badgeBackground = NSView()

	override init(frame: NSRect) {
		super.init(frame: frame)
		wantsLayer = true
		layer?.cornerRadius = 6
		imageView.imageScaling = .scaleProportionallyUpOrDown
		imageView.frame = NSRect(x: 8, y: 5, width: 24, height: 24)
		dot.wantsLayer = true
		dot.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.85).cgColor
		dot.layer?.cornerRadius = 1.5
		dot.frame = NSRect(x: 18.5, y: 0, width: 3, height: 3)
		badgeBackground.wantsLayer = true
		badgeBackground.layer?.backgroundColor = NSColor.systemRed.cgColor
		badgeBackground.layer?.cornerRadius = 7
		badge.font = .systemFont(ofSize: 9, weight: .bold)
		badge.textColor = .white
		badge.alignment = .center
		addSubview(imageView)
		addSubview(dot)
		addSubview(badgeBackground)
		addSubview(badge)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(app: DockApp, icon: NSImage?, badgeText: String?, isFrontmost: Bool, showsIndicator: Bool, isLaunching: Bool) {
		imageView.image = icon
		imageView.alphaValue = isLaunching ? 0.45 : (!app.isRunning && !app.isPinned ? 0.6 : 1)
		dot.isHidden = !(app.isRunning && showsIndicator)
		layer?.backgroundColor = isFrontmost ? NSColor.white.withAlphaComponent(0.16).cgColor : nil
		if let text = badgeText {
			badge.stringValue = text
			let width = max(14, badge.intrinsicContentSize.width + 6)
			badgeBackground.frame = NSRect(x: DockItemView.size.width - width - 1, y: DockItemView.size.height - 14, width: width, height: 14)
			badge.frame = NSRect(x: badgeBackground.frame.minX, y: badgeBackground.frame.minY - 1, width: width, height: 14)
			badgeBackground.isHidden = false
			badge.isHidden = false
		} else {
			badgeBackground.isHidden = true
			badge.isHidden = true
		}
		toolTip = app.name
		setAccessibilityLabel(app.name)
	}
}

internal final class DockTouchBarItem: NSCustomTouchBarItem, NSScrubberDataSource, NSScrubberDelegate {

	private let stackView = NSStackView()
	private let scrubber = NSScrubber(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
	private let separator = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 20))
	private let foldersStack = NSStackView()
	private var scrubberWidth: NSLayoutConstraint?

	private var apps: [DockApp] = []
	private var folders: [DockFolderEntry] = []
	private var badges: [String: String] = [:]
	private var icons: [String: NSImage] = [:]
	private var refreshTimer: Timer?
	private var reloadPending = false
	private static let itemIdentifier = NSUserInterfaceItemIdentifier("DockItemView")
	/// Widest the app list grows before it scrolls, so the other items keep their room.
	private static let maxScrubberWidth: CGFloat = 400

	override init(identifier: NSTouchBarItem.Identifier) {
		super.init(identifier: identifier)
		customizationLabel = "Dock"
		stackView.orientation = .horizontal
		stackView.alignment = .centerY
		stackView.spacing = 6
		view = stackView

		scrubber.register(DockItemView.self, forItemIdentifier: DockTouchBarItem.itemIdentifier)
		scrubber.dataSource = self
		scrubber.delegate = self
		scrubber.mode = .free
		scrubber.isContinuous = false
		scrubber.showsAdditionalContentIndicators = true
		scrubber.selectionBackgroundStyle = nil
		scrubber.itemAlignment = .none
		scrubber.translatesAutoresizingMaskIntoConstraints = false
		scrubberWidth = scrubber.widthAnchor.constraint(equalToConstant: 200)
		scrubberWidth?.isActive = true
		scrubber.heightAnchor.constraint(equalToConstant: 30).isActive = true

		separator.wantsLayer = true
		separator.layer?.backgroundColor = NSColor.darkGray.cgColor
		separator.translatesAutoresizingMaskIntoConstraints = false
		separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
		separator.heightAnchor.constraint(equalToConstant: 20).isActive = true
		foldersStack.orientation = .horizontal
		foldersStack.spacing = 4

		stackView.addArrangedSubview(scrubber)
		stackView.addArrangedSubview(separator)
		stackView.addArrangedSubview(foldersStack)

		let center = NSWorkspace.shared.notificationCenter
		for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
					 NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification,
					 NSWorkspace.didUnhideApplicationNotification] {
			center.addObserver(self, selector: #selector(scheduleReload), name: name, object: nil)
		}
		NotificationCenter.default.addObserver(self, selector: #selector(scheduleReload), name: .dockDidChange, object: nil)
		reload()
		// Badges and the system Dock's own list change without a workspace notification.
		refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
			self?.refreshBadges()
			self?.reload()
		}
		refreshBadges()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		refreshTimer?.invalidate()
		NSWorkspace.shared.notificationCenter.removeObserver(self)
		NotificationCenter.default.removeObserver(self)
	}

	// MARK: Data

	/// Launch and termination notifications arrive in bursts; rebuild once per run loop turn.
	@objc private func scheduleReload() {
		guard !reloadPending else {
			return
		}
		reloadPending = true
		DispatchQueue.main.async { [weak self] in
			self?.reloadPending = false
			self?.reload()
		}
	}

	private func reload() {
		let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")
		let running = NSWorkspace.shared.runningApplications.compactMap { app -> DockRunningEntry? in
			guard app.activationPolicy == .regular, let identifier = app.bundleIdentifier else {
				return nil
			}
			return DockRunningEntry(bundleIdentifier: identifier, name: app.localizedName ?? identifier, pid: app.processIdentifier)
		}
		let newApps = DockLogic.merge(pinned: DockLogic.pinnedApps(from: domain), running: running,
									  hideFinder: Preferences[.hideFinder], onlyRunning: Preferences[.showOnlyRunningApps])
		let newFolders = Preferences[.hidePersistentItems] ? [] : DockLogic.folders(from: domain)
		let appsChanged = newApps != apps
		let foldersChanged = newFolders != folders || foldersStack.arrangedSubviews.count != newFolders.count + (Preferences[.hideTrash] ? 0 : 1)
		apps = newApps
		folders = newFolders
		let spacing: CGFloat = Preferences[.itemSpacing]
		if let flow = scrubber.scrubberLayout as? NSScrubberFlowLayout {
			if flow.itemSpacing != spacing {
				flow.itemSpacing = spacing
			}
		} else {
			let layout = NSScrubberFlowLayout()
			layout.itemSize = DockItemView.size
			layout.itemSpacing = spacing
			scrubber.scrubberLayout = layout
		}
		let step = DockItemView.size.width + spacing
		scrubberWidth?.constant = min(max(step * CGFloat(apps.count) - spacing, 0), DockTouchBarItem.maxScrubberWidth)
		if appsChanged {
			scrubber.reloadData()
		} else {
			// Same apps: only active/launching state changed.
			for index in 0..<apps.count {
				if let itemView = scrubber.itemViewForItem(at: index) as? DockItemView {
					configure(itemView, at: index)
				}
			}
		}
		if foldersChanged {
			rebuildFolders()
		}
	}

	private func refreshBadges() {
		guard Preferences[.hideBadges] == false else {
			if !badges.isEmpty {
				badges = [:]
				scrubber.reloadData()
			}
			return
		}
		DispatchQueue.global(qos: .utility).async { [weak self] in
			let latest = DockBadges.read()
			DispatchQueue.main.async {
				guard let self = self, latest != self.badges else {
					return
				}
				self.badges = latest
				self.scrubber.reloadData()
			}
		}
	}

	private func icon(for app: DockApp) -> NSImage? {
		if let cached = icons[app.bundleIdentifier] {
			return cached
		}
		let image: NSImage?
		if let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first, let icon = running.icon {
			image = icon
		} else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
			image = NSWorkspace.shared.icon(forFile: url.path)
		} else {
			image = nil
		}
		if let image = image {
			icons[app.bundleIdentifier] = image
		}
		return image
	}

	// MARK: Folders and Trash

	private func rebuildFolders() {
		foldersStack.arrangedSubviews.forEach {
			foldersStack.removeArrangedSubview($0)
			$0.removeFromSuperview()
		}
		for (index, folder) in folders.enumerated() {
			foldersStack.addArrangedSubview(makeButton(icon: NSWorkspace.shared.icon(forFile: folder.url.path), title: folder.name, tag: index))
		}
		if !Preferences[.hideTrash] {
			let url = URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")
			let isEmpty = ((try? FileManager.default.contentsOfDirectory(atPath: url.path))?.isEmpty) ?? true
			let name = isEmpty ? "TrashIcon" : "FullTrashIcon"
			let icon = NSImage(contentsOfFile: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/\(name).icns")
				?? NSWorkspace.shared.icon(forFile: url.path)
			foldersStack.addArrangedSubview(makeButton(icon: icon, title: "Trash".localized, tag: -1))
		}
		let hasContent = !foldersStack.arrangedSubviews.isEmpty
		foldersStack.isHidden = !hasContent
		separator.isHidden = !hasContent || apps.isEmpty
	}

	private func makeButton(icon: NSImage, title: String, tag: Int) -> NSButton {
		let image = icon.copy() as? NSImage ?? icon
		image.size = NSSize(width: 24, height: 24)
		let button = NSButton(image: image, target: self, action: #selector(openFolder(_:)))
		button.isBordered = false
		button.imagePosition = .imageOnly
		button.tag = tag
		button.toolTip = title
		button.setAccessibilityLabel(title)
		button.widthAnchor.constraint(equalToConstant: DockItemView.size.width).isActive = true
		return button
	}

	@objc private func openFolder(_ sender: NSButton) {
		if sender.tag >= 0, folders.indices.contains(sender.tag) {
			NSWorkspace.shared.open(folders[sender.tag].url)
		} else {
			NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.Trash"))
		}
	}

	// MARK: Scrubber

	func numberOfItems(for scrubber: NSScrubber) -> Int {
		return apps.count
	}

	func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
		let view = scrubber.makeItem(withIdentifier: DockTouchBarItem.itemIdentifier, owner: nil) as? DockItemView ?? DockItemView()
		configure(view, at: index)
		return view
	}

	private func configure(_ view: DockItemView, at index: Int) {
		guard apps.indices.contains(index) else {
			return
		}
		let app = apps[index]
		let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first
		view.configure(app: app, icon: icon(for: app),
					   badgeText: DockLogic.badgeText(badges[app.name]),
					   isFrontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier == app.bundleIdentifier,
					   showsIndicator: !Preferences[.hideRunningIndicator],
					   isLaunching: running.map { !$0.isFinishedLaunching } ?? false)
	}

	func scrubber(_ scrubber: NSScrubber, didSelectItemAt selectedIndex: Int) {
		defer {
			scrubber.selectedIndex = -1
		}
		guard apps.indices.contains(selectedIndex) else {
			return
		}
		launch(apps[selectedIndex])
	}

	/// Same result as clicking the icon in the Dock: unhides, reopens a window when there is none, or launches.
	private func launch(_ app: DockApp) {
		if let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first, running.isHidden {
			running.unhide()
		}
		guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
			NSSound.beep()
			return
		}
		let configuration = NSWorkspace.OpenConfiguration()
		configuration.activates = true
		NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
			if error != nil {
				NSSound.beep()
			}
		}
	}
}
