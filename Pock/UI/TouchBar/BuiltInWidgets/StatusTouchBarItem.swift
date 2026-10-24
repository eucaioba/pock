//
//  StatusTouchBarItem.swift
//  Pock
//
//  Built-in replacement for the Status widget: input source, Wi-Fi, battery and clock.
//  Everything is event driven except Wi-Fi signal, which CoreWLAN only reports by polling.
//

import AppKit
import Carbon.HIToolbox
import CoreWLAN
import IOKit.ps

extension NSTouchBarItem.Identifier {
	static let status = NSTouchBarItem.Identifier("com.pigigaldi.pock.StatusItem")
}

extension NSNotification.Name {
	static let statusDidChange = NSNotification.Name("statusDidChange")
}

internal final class StatusTouchBarItem: NSCustomTouchBarItem {

	private let stackView = NSStackView()
	private let inputButton = NSButton(title: "", target: nil, action: nil)
	private let wifiView = NSImageView()
	private let batteryButton = NSButton(title: "", target: nil, action: nil)
	private let clockButton = NSButton(title: "", target: nil, action: nil)

	private var clockTimer: Timer?
	private var wifiTimer: Timer?
	private var powerSource: CFRunLoopSource?
	private let clockFormatter = DateFormatter()

	override init(identifier: NSTouchBarItem.Identifier) {
		super.init(identifier: identifier)
		customizationLabel = "Status"
		stackView.orientation = .horizontal
		stackView.alignment = .centerY
		stackView.spacing = 10
		// Never clip the clock: when the bar is full, the scrolling Dock or App Controls give way instead.
		stackView.setClippingResistancePriority(.required, for: .horizontal)
		stackView.setHuggingPriority(.required, for: .horizontal)
		visibilityPriority = .high
		view = stackView
		for button in [inputButton, batteryButton, clockButton] {
			button.isBordered = false
			button.target = self
			button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
		}
		inputButton.action = #selector(selectNextInputSource)
		batteryButton.action = #selector(openBatterySettings)
		batteryButton.imagePosition = .imageTrailing
		clockButton.action = #selector(openCalendar)
		wifiView.imageScaling = .scaleProportionallyDown
		wifiView.widthAnchor.constraint(equalToConstant: 22).isActive = true
		wifiView.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(openWiFiSettings)))
		rebuild()
		NotificationCenter.default.addObserver(self, selector: #selector(rebuild), name: .statusDidChange, object: nil)
		DistributedNotificationCenter.default().addObserver(self, selector: #selector(updateInputSource),
															 name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(rebuild), name: NSWorkspace.didWakeNotification, object: nil)
		startPowerNotifications()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		clockTimer?.invalidate()
		wifiTimer?.invalidate()
		if let source = powerSource {
			CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
		}
		NotificationCenter.default.removeObserver(self)
		DistributedNotificationCenter.default().removeObserver(self)
		NSWorkspace.shared.notificationCenter.removeObserver(self)
	}

	// MARK: Layout

	@objc private func rebuild() {
		stackView.arrangedSubviews.forEach {
			stackView.removeArrangedSubview($0)
			$0.removeFromSuperview()
		}
		if Preferences[.shouldShowLangItem] {
			stackView.addArrangedSubview(inputButton)
			updateInputSource()
		}
		wifiTimer?.invalidate()
		if Preferences[.shouldShowWifiItem] {
			stackView.addArrangedSubview(wifiView)
			updateWiFi()
			wifiTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
				self?.updateWiFi()
			}
		}
		if Preferences[.shouldShowPowerItem], hasBattery {
			stackView.addArrangedSubview(batteryButton)
			updateBattery()
		}
		clockTimer?.invalidate()
		if Preferences[.shouldShowDateItem] {
			stackView.addArrangedSubview(clockButton)
			// An explicit String: `dateFormat` is `String!`, which would make the lookup return nil instead of the default.
			let format: String = Preferences[.timeFormatTextField]
			clockFormatter.dateFormat = format
			clockFormatter.locale = Locale.autoupdatingCurrent
			updateClock()
		}
	}

	// MARK: Input source

	@objc private func updateInputSource() {
		guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
			return
		}
		let languages = (property(of: source, kTISPropertyInputSourceLanguages) as? [String]) ?? []
		let name = (property(of: source, kTISPropertyLocalizedName) as? String) ?? ""
		inputButton.title = StatusLogic.inputSourceLabel(languages: languages, name: name)
		inputButton.toolTip = name
	}

	private func property(of source: TISInputSource, _ key: CFString) -> AnyObject? {
		guard let pointer = TISGetInputSourceProperty(source, key) else {
			return nil
		}
		return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
	}

	/// Cycles through the enabled keyboard layouts and input methods, like ⌃Space.
	@objc private func selectNextInputSource() {
		let filter = [kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
					  kTISPropertyInputSourceIsSelectCapable as String: true] as CFDictionary
		guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource], list.count > 1,
			  let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
			return
		}
		let currentID = property(of: current, kTISPropertyInputSourceID) as? String
		let index = list.firstIndex { (property(of: $0, kTISPropertyInputSourceID) as? String) == currentID } ?? -1
		TISSelectInputSource(list[(index + 1) % list.count])
	}

	// MARK: Wi-Fi

	private func updateWiFi() {
		guard #available(macOS 11.0, *) else {
			return
		}
		let interface = CWWiFiClient.shared().interface()
		let bars = StatusLogic.wifiBars(rssi: interface?.rssiValue() ?? 0)
		if interface?.powerOn() != true {
			wifiView.image = NSImage(systemSymbolName: "wifi.slash", accessibilityDescription: "Wi-Fi")
		} else if bars == 0 {
			wifiView.image = NSImage(systemSymbolName: "wifi.exclamationmark", accessibilityDescription: "Wi-Fi")
		} else if #available(macOS 13.0, *) {
			wifiView.image = NSImage(systemSymbolName: "wifi", variableValue: Double(bars) / 3, accessibilityDescription: "Wi-Fi")
		} else {
			wifiView.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: "Wi-Fi")
		}
	}

	// MARK: Battery

	private var hasBattery: Bool {
		return batteryInfo != nil
	}

	private var batteryInfo: [String: Any]? {
		guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
			  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
			return nil
		}
		for source in sources {
			if let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
			   info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType {
				return info
			}
		}
		return nil
	}

	private func startPowerNotifications() {
		let context = Unmanaged.passUnretained(self).toOpaque()
		guard let source = IOPSNotificationCreateRunLoopSource({ context in
			guard let context = context else {
				return
			}
			Unmanaged<StatusTouchBarItem>.fromOpaque(context).takeUnretainedValue().updateBattery()
		}, context)?.takeRetainedValue() else {
			return
		}
		powerSource = source
		CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
	}

	private func updateBattery() {
		guard let info = batteryInfo else {
			return
		}
		let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
		let maximum = max(1, info[kIOPSMaxCapacityKey] as? Int ?? 100)
		let percent = Int((Double(current) / Double(maximum) * 100).rounded())
		let charging = info[kIOPSIsChargingKey] as? Bool ?? false
		let pluggedIn = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
		batteryButton.title = Preferences[.shouldShowBatteryPercentage] ? "\(percent)%" : ""
		if Preferences[.shouldShowBatteryIcon], #available(macOS 11.0, *) {
			let symbol = StatusLogic.batterySymbol(percent: percent, charging: charging, pluggedIn: pluggedIn)
			batteryButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "\(percent)%")
			batteryButton.contentTintColor = percent <= 10 && !pluggedIn ? .systemRed : charging ? .systemGreen : nil
		} else {
			batteryButton.image = nil
		}
		batteryButton.toolTip = "\(percent)%"
	}

	// MARK: Clock

	private func updateClock() {
		let now = Date()
		clockButton.title = clockFormatter.string(from: now)
		let format: String = Preferences[.timeFormatTextField]
		clockTimer?.invalidate()
		clockTimer = Timer.scheduledTimer(withTimeInterval: StatusLogic.clockDelay(format: format, now: now) + 0.01, repeats: false) { [weak self] _ in
			self?.updateClock()
		}
	}

	// MARK: Actions

	@objc private func openBatterySettings() {
		open("x-apple.systempreferences:com.apple.Battery-Settings.extension")
	}

	@objc private func openWiFiSettings() {
		open("x-apple.systempreferences:com.apple.wifi-settings-extension")
	}

	@objc private func openCalendar() {
		NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
	}

	private func open(_ string: String) {
		if let url = URL(string: string) {
			NSWorkspace.shared.open(url)
		}
	}
}
