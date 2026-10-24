//
//  ControlsTouchBarItem.swift
//  Pock
//
//  Built-in replacement for the Control Center widget: brightness, volume and session controls.
//

import AppKit
import PockKit

extension NSTouchBarItem.Identifier {
	static let controls = NSTouchBarItem.Identifier("com.pigigaldi.pock.Controls")
}

extension NSNotification.Name {
	static let controlsDidChange = NSNotification.Name("controlsDidChange")
}

internal enum ControlsButton: String, CaseIterable {
	case brightness, volume, mute, lock, sleepDisplay, screenSaver, focus

	static let defaultEnabled: [ControlsButton] = [.brightness, .volume, .mute, .lock]

	static var enabled: [ControlsButton] {
		let raw: [String] = Preferences[.controlsButtons]
		return ControlsButton.allCases.filter { raw.contains($0.rawValue) }
	}

	var title: String {
		return "controls.\(rawValue)".localized
	}

	var symbol: String {
		switch self {
		case .brightness:
			return "sun.max.fill"
		case .volume:
			return "speaker.wave.2.fill"
		case .mute:
			return "speaker.slash.fill"
		case .lock:
			return "lock.fill"
		case .sleepDisplay:
			return "moon.zzz.fill"
		case .screenSaver:
			return "sparkles.tv"
		case .focus:
			return "moon.fill"
		}
	}
}

internal final class ControlsTouchBarItem: NSCustomTouchBarItem {

	private let stackView = NSStackView()
	private var buttons: [ControlsButton: NSButton] = [:]
	private var refreshTimer: Timer?

	override init(identifier: NSTouchBarItem.Identifier) {
		super.init(identifier: identifier)
		customizationLabel = "Controls"
		stackView.orientation = .horizontal
		stackView.spacing = 4
		view = stackView
		rebuild()
		NotificationCenter.default.addObserver(self, selector: #selector(rebuild), name: .controlsDidChange, object: nil)
		// Volume and brightness also change from keys and other apps; the reads are cheap.
		refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
			self?.refresh()
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		refreshTimer?.invalidate()
		NotificationCenter.default.removeObserver(self)
	}

	@objc private func rebuild() {
		stackView.arrangedSubviews.forEach {
			stackView.removeArrangedSubview($0)
			$0.removeFromSuperview()
		}
		buttons.removeAll()
		for control in ControlsButton.enabled {
			let button = makeButton(for: control)
			buttons[control] = button
			stackView.addArrangedSubview(button)
		}
		refresh()
	}

	private func makeButton(for control: ControlsButton) -> NSButton {
		let button: NSButton
		if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: control.symbol, accessibilityDescription: control.title) {
			button = NSButton(image: image, target: self, action: #selector(handle(_:)))
		} else {
			button = NSButton(title: control.title, target: self, action: #selector(handle(_:)))
		}
		if button.image != nil {
			// Only brightness and volume show a value next to the icon.
			button.title = ""
		}
		button.identifier = NSUserInterfaceItemIdentifier(control.rawValue)
		button.toolTip = control.title
		button.setAccessibilityLabel(control.title)
		button.imagePosition = .imageLeading
		button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
		button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
		return button
	}

	private func refresh() {
		func percent(_ value: Float?) -> String {
			return value.map { "\(Int(($0 * 100).rounded()))%" } ?? ""
		}
		let muted = SystemVolume.isMuted
		buttons[.brightness]?.title = percent(DisplayBrightness.level)
		buttons[.volume]?.title = muted ? "" : percent(SystemVolume.level)
		buttons[.mute]?.bezelColor = muted ? .controlAccentColor : nil
		if #available(macOS 11.0, *), let volume = buttons[.volume] {
			let level = SystemVolume.level ?? 0
			let symbol = muted ? "speaker.slash.fill" : level < 0.01 ? "speaker.fill" : level < 0.34 ? "speaker.wave.1.fill" : level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
			volume.image = NSImage(systemSymbolName: symbol, accessibilityDescription: ControlsButton.volume.title)
		}
	}

	@objc private func handle(_ sender: NSButton) {
		guard let raw = sender.identifier?.rawValue, let control = ControlsButton(rawValue: raw) else {
			return
		}
		switch control {
		case .brightness:
			SliderTouchBarController.show(.brightness)
		case .volume:
			SliderTouchBarController.show(.volume)
		case .mute:
			SystemVolume.setMuted(!SystemVolume.isMuted)
		case .lock:
			SessionControls.lockScreen()
		case .sleepDisplay:
			SessionControls.sleepDisplay()
		case .screenSaver:
			SessionControls.startScreenSaver()
		case .focus:
			SessionControls.runShortcut(named: Preferences[.focusShortcutName])
		}
		refresh()
	}
}

/// Full-width slider pushed over Pock, like the system Control Strip's expanded brightness and volume.
internal final class SliderTouchBarController: PKTouchBarController {

	enum Kind {
		case brightness, volume
	}

	private var kind: Kind = .volume
	private var dismissTimer: Timer?
	private weak var slider: NSSliderTouchBarItem?

	static func show(_ kind: Kind) {
		guard let navigationController = AppController.shared.navigationController else {
			return
		}
		let controller = SliderTouchBarController()
		controller.kind = kind
		navigationController.push(controller)
		controller.scheduleDismiss()
	}

	private var value: Float {
		switch kind {
		case .brightness:
			return DisplayBrightness.level ?? 0
		case .volume:
			return SystemVolume.isMuted ? 0 : SystemVolume.level ?? 0
		}
	}

	override func makeTouchBar() -> NSTouchBar? {
		let bar = NSTouchBar()
		let closeItem = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("Pock.Slider.Close"))
		let closeButton: NSButton
		if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "general.action.close".localized) {
			closeButton = NSButton(image: image, target: self, action: #selector(close))
		} else {
			closeButton = NSButton(title: "×", target: self, action: #selector(close))
		}
		closeItem.view = closeButton
		let item = NSSliderTouchBarItem(identifier: NSTouchBarItem.Identifier("Pock.Slider.Value"))
		item.slider.minValue = 0
		item.slider.maxValue = 1
		item.slider.doubleValue = Double(value)
		item.slider.isContinuous = true
		item.target = self
		item.action = #selector(sliderDidChange(_:))
		item.maximumSliderWidth = 640
		let low: String, high: String
		switch kind {
		case .brightness:
			(low, high) = ("sun.min", "sun.max.fill")
		case .volume:
			(low, high) = ("speaker.fill", "speaker.wave.3.fill")
		}
		if #available(macOS 11.0, *),
		   let lowImage = NSImage(systemSymbolName: low, accessibilityDescription: nil),
		   let highImage = NSImage(systemSymbolName: high, accessibilityDescription: nil) {
			item.minimumValueAccessory = NSSliderAccessory(image: lowImage)
			item.maximumValueAccessory = NSSliderAccessory(image: highImage)
		}
		slider = item
		bar.templateItems = [closeItem, item]
		bar.defaultItemIdentifiers = [closeItem.identifier, item.identifier]
		return bar
	}

	@objc private func sliderDidChange(_ sender: NSSliderTouchBarItem) {
		let level = Float(sender.slider.doubleValue)
		switch kind {
		case .brightness:
			DisplayBrightness.setLevel(level)
		case .volume:
			// Flicking all the way left often stops just short of zero; treat the bottom edge as mute.
			if level < 0.03 {
				SystemVolume.setMuted(true)
			} else {
				SystemVolume.setLevel(level)
			}
		}
		scheduleDismiss()
	}

	private func scheduleDismiss() {
		dismissTimer?.invalidate()
		dismissTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
			self?.close()
		}
	}

	@objc private func close() {
		dismissTimer?.invalidate()
		dismissTimer = nil
		if isVisible {
			dismiss()
		}
	}
}
