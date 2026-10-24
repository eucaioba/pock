//
//  ModifierTouchBarController.swift
//  Pock
//
//  Touch Bars shown while holding `⌘` (apps), `⌥` (system controls) or `⌃` (window layout).
//

import AppKit
import PockKit

internal final class ModifierTouchBarController: PKTouchBarController {

	private(set) var mode: ModifierTouchBarMode = .appSwitcher
	private var applications: [NSRunningApplication] = []
	private var brightnessLabel: NSTextField?
	private var volumeLabel: NSTextField?
	private var muteButton: NSButton?

	private enum SystemAction: Int {
		case brightnessDown, brightnessUp, volumeDown, mute, volumeUp, missionControl, applications, sleepDisplay
	}

	convenience init(mode: ModifierTouchBarMode) {
		self.init()
		self.mode = mode
	}

	override func makeTouchBar() -> NSTouchBar? {
		let bar = NSTouchBar()
		let views: [NSView]
		switch mode {
		case .appSwitcher:
			views = appSwitcherViews()
		case .controlStrip:
			views = controlStripViews()
		case .windowLayout:
			views = windowLayoutViews()
		}
		let items: [NSTouchBarItem] = views.enumerated().map { index, view in
			let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("Pock.Modifier.\(mode.rawValue).\(index)"))
			item.view = view
			return item
		}
		bar.templateItems = Set(items)
		bar.defaultItemIdentifiers = items.map(\.identifier)
		return bar
	}

	// MARK: Building blocks

	private func label(_ text: String, width: CGFloat? = nil) -> NSTextField {
		let label = NSTextField(labelWithString: text)
		label.font = .systemFont(ofSize: 12, weight: .medium)
		label.textColor = .secondaryLabelColor
		label.lineBreakMode = .byTruncatingTail
		if let width = width {
			label.alignment = .center
			label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
			label.widthAnchor.constraint(equalToConstant: width).isActive = true
		}
		return label
	}

	private func button(symbol: String, fallback: String, label: String, tag: Int, action: Selector) -> NSButton {
		let button: NSButton
		if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label) {
			button = NSButton(image: image, target: self, action: action)
		} else {
			button = NSButton(title: fallback, target: self, action: action)
		}
		button.tag = tag
		button.toolTip = label
		button.setAccessibilityLabel(label)
		button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
		return button
	}

	private func group(_ views: [NSView], spacing: CGFloat = 4) -> NSStackView {
		let stack = NSStackView(views: views)
		stack.orientation = .horizontal
		stack.spacing = spacing
		return stack
	}

	// MARK: ⌘ Applications

	private func appSwitcherViews() -> [NSView] {
		let ownPID = ProcessInfo.processInfo.processIdentifier
		let running = NSWorkspace.shared.runningApplications.filter {
			$0.activationPolicy == .regular && $0.processIdentifier != ownPID && !$0.isTerminated
		}
		let order = ModifierTouchBarMonitor.applicationOrder.sorted(running.map(\.processIdentifier))
		applications = order.compactMap { pid in running.first(where: { $0.processIdentifier == pid }) }
		let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
		let buttons: [NSView] = applications.enumerated().map { index, app in
			let icon = (app.icon?.copy() as? NSImage) ?? NSImage(named: NSImage.applicationIconName)!
			icon.size = NSSize(width: 24, height: 24)
			let button = NSButton(image: icon, target: self, action: #selector(activateApplication(_:)))
			button.tag = index
			button.imagePosition = .imageOnly
			button.toolTip = app.localizedName
			button.setAccessibilityLabel(app.localizedName)
			button.widthAnchor.constraint(equalToConstant: 46).isActive = true
			if app.processIdentifier == frontmost {
				button.bezelColor = .controlAccentColor
			} else if app.isHidden {
				button.alphaValue = 0.55
			}
			return button
		}
		let stack = group(buttons, spacing: 6)
		stack.frame = NSRect(origin: .zero, size: stack.fittingSize)
		let scroll = NSScrollView()
		scroll.documentView = stack
		scroll.drawsBackground = false
		scroll.hasHorizontalScroller = false
		let maxWidth: CGFloat = TouchBarHelper.isSystemControlStripVisible ? 780 : 960
		scroll.widthAnchor.constraint(equalToConstant: min(stack.fittingSize.width, maxWidth)).isActive = true
		scroll.heightAnchor.constraint(equalToConstant: 30).isActive = true
		return [label("⌘"), scroll]
	}

	@objc private func activateApplication(_ sender: NSButton) {
		guard applications.indices.contains(sender.tag) else {
			return
		}
		let app = applications[sender.tag]
		if let url = app.bundleURL {
			// Same as clicking in the Dock: unhides the app and reopens a window when it has none.
			let configuration = NSWorkspace.OpenConfiguration()
			configuration.activates = true
			NSWorkspace.shared.openApplication(at: url, configuration: configuration)
		} else {
			app.unhide()
			app.activate(options: .activateAllWindows)
		}
	}

	// MARK: ⌥ System controls

	private func controlStripViews() -> [NSView] {
		let brightness = label("", width: 40)
		let volume = label("", width: 40)
		brightnessLabel = brightness
		volumeLabel = volume
		let mute = button(symbol: "speaker.slash.fill", fallback: "Mute", label: "modifier-bar.mute".localized,
						  tag: SystemAction.mute.rawValue, action: #selector(performSystemAction(_:)))
		muteButton = mute
		var views: [NSView] = [
			label("⌥"),
			group([
				button(symbol: "sun.min", fallback: "☼−", label: "modifier-bar.brightness-down".localized,
					   tag: SystemAction.brightnessDown.rawValue, action: #selector(performSystemAction(_:))),
				brightness,
				button(symbol: "sun.max", fallback: "☼+", label: "modifier-bar.brightness-up".localized,
					   tag: SystemAction.brightnessUp.rawValue, action: #selector(performSystemAction(_:)))
			]),
			group([
				button(symbol: "speaker.wave.1.fill", fallback: "Vol−", label: "modifier-bar.volume-down".localized,
					   tag: SystemAction.volumeDown.rawValue, action: #selector(performSystemAction(_:))),
				volume,
				button(symbol: "speaker.wave.3.fill", fallback: "Vol+", label: "modifier-bar.volume-up".localized,
					   tag: SystemAction.volumeUp.rawValue, action: #selector(performSystemAction(_:))),
				mute
			]),
			button(symbol: "rectangle.3.group", fallback: "Mission Control", label: "Mission Control",
				   tag: SystemAction.missionControl.rawValue, action: #selector(performSystemAction(_:)))
		]
		if ModifierTouchBarController.applicationsURL != nil {
			views.append(button(symbol: "square.grid.3x3", fallback: "Apps", label: "modifier-bar.applications".localized,
								tag: SystemAction.applications.rawValue, action: #selector(performSystemAction(_:))))
		}
		views.append(button(symbol: "moon.zzz", fallback: "Sleep", label: "modifier-bar.sleep-display".localized,
							tag: SystemAction.sleepDisplay.rawValue, action: #selector(performSystemAction(_:))))
		updateSystemLabels()
		return views
	}

	/// Apps (macOS 26) or Launchpad (earlier releases).
	private static var applicationsURL: URL? {
		return ["/System/Applications/Apps.app", "/System/Applications/Launchpad.app"]
			.map { URL(fileURLWithPath: $0) }
			.first { FileManager.default.fileExists(atPath: $0.path) }
	}

	private func updateSystemLabels() {
		func percent(_ value: Float?) -> String {
			return value.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
		}
		brightnessLabel?.stringValue = percent(DisplayBrightness.level)
		let muted = SystemVolume.isMuted
		volumeLabel?.stringValue = muted ? "modifier-bar.muted".localized : percent(SystemVolume.level)
		muteButton?.bezelColor = muted ? .controlAccentColor : nil
	}

	@objc private func performSystemAction(_ sender: NSButton) {
		switch SystemAction(rawValue: sender.tag) {
		case .brightnessDown:
			DisplayBrightness.change(by: -DisplayBrightness.step)
		case .brightnessUp:
			DisplayBrightness.change(by: DisplayBrightness.step)
		case .volumeDown:
			SystemVolume.change(by: -SystemVolume.step)
		case .volumeUp:
			SystemVolume.change(by: SystemVolume.step)
		case .mute:
			SystemVolume.setMuted(!SystemVolume.isMuted)
		case .missionControl:
			NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
		case .applications:
			if let url = ModifierTouchBarController.applicationsURL {
				NSWorkspace.shared.open(url)
			}
		case .sleepDisplay:
			SessionControls.sleepDisplay()
		case .none:
			return
		}
		updateSystemLabels()
	}

	// MARK: ⌃ Window layout

	private func windowLayoutViews() -> [NSView] {
		let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
		guard WindowManager.isTrusted else {
			let allow = NSButton(title: "modifier-bar.allow-accessibility".localized, target: self, action: #selector(requestAccessibility))
			allow.bezelColor = .controlAccentColor
			return [label("⌃"), label("modifier-bar.accessibility-required".localized), allow]
		}
		func layoutButton(_ layout: WindowLayout, _ symbol: String, _ fallback: String) -> NSButton {
			let index = WindowLayout.allCases.firstIndex(of: layout) ?? 0
			return button(symbol: symbol, fallback: fallback, label: "modifier-bar.window.\(layout.rawValue)".localized,
						  tag: index, action: #selector(applyLayout(_:)))
		}
		var views: [NSView] = [
			label("⌃ " + appName),
			group([
				layoutButton(.leftHalf, "rectangle.lefthalf.filled", "◧"),
				layoutButton(.rightHalf, "rectangle.righthalf.filled", "◨"),
				layoutButton(.topHalf, "rectangle.tophalf.filled", "⬒"),
				layoutButton(.bottomHalf, "rectangle.bottomhalf.filled", "⬓")
			]),
			group([
				layoutButton(.leftThird, "rectangle.leftthird.inset.filled", "⅓◀"),
				layoutButton(.centerThird, "rectangle.center.inset.filled", "⅓"),
				layoutButton(.rightThird, "rectangle.rightthird.inset.filled", "▶⅓")
			]),
			group([
				layoutButton(.center, "rectangle.inset.filled", "▣"),
				layoutButton(.maximize, "arrow.up.left.and.arrow.down.right", "⤢")
			])
		]
		if NSScreen.screens.count > 1 {
			views.append(layoutButton(.nextDisplay, "rectangle.on.rectangle", "⇥"))
		}
		return views
	}

	@objc private func applyLayout(_ sender: NSButton) {
		guard WindowLayout.allCases.indices.contains(sender.tag) else {
			return
		}
		if !WindowManager.apply(WindowLayout.allCases[sender.tag]) {
			NSSound.beep()
		}
	}

	@objc private func requestAccessibility() {
		WindowManager.requestAccess()
	}
}
