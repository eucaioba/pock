//
//  ModifierTouchBarMonitor.swift
//  Pock
//
//  Shows a dedicated Touch Bar while `⌘`, `⌥` or `⌃` is held on its own.
//

import AppKit

internal final class ModifierTouchBarMonitor {

	/// How long the modifier must be held alone before the bar appears.
	private static let holdDelay: TimeInterval = 0.45
	private static let watchInterval: TimeInterval = 0.08

	/// Provides the controller to show, or `nil` when Pock is not on screen.
	private let present: (ModifierTouchBarMode) -> ModifierTouchBarController?

	private var monitors: [Any] = []
	private var holdTimer: Timer?
	private var watchTimer: Timer?
	private var pendingMode: ModifierTouchBarMode?
	private var pendingInputCount: [UInt32] = []
	private var visibleKeyCount: UInt32 = 0
	private var controller: ModifierTouchBarController?

	private(set) static var applicationOrder = ApplicationOrder()

	init(present: @escaping (ModifierTouchBarMode) -> ModifierTouchBarController?) {
		self.present = present
		if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
			self?.modifiersDidChange(event.modifierFlags)
		}) {
			monitors.append(global)
		}
		if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
			self?.modifiersDidChange(event.modifierFlags)
			return event
		}) {
			monitors.append(local)
		}
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationDidActivate(_:)),
														  name: NSWorkspace.didActivateApplicationNotification, object: nil)
		if let frontmost = NSWorkspace.shared.frontmostApplication {
			ModifierTouchBarMonitor.applicationOrder.activated(frontmost.processIdentifier)
		}
	}

	deinit {
		monitors.forEach(NSEvent.removeMonitor)
		NSWorkspace.shared.notificationCenter.removeObserver(self)
		cancelPending()
		hide()
	}

	@objc private func applicationDidActivate(_ notification: Notification) {
		if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
			ModifierTouchBarMonitor.applicationOrder.activated(app.processIdentifier)
		}
	}

	/// Keyboard, click and scroll counters. Any change means the modifier was used for a shortcut.
	private static var inputCount: [UInt32] {
		let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
		return types.map { CGEventSource.counterForEventType(.combinedSessionState, eventType: $0) }
	}

	private static var keyDownCount: UInt32 {
		return CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
	}

	private func modifiersDidChange(_ flags: NSEvent.ModifierFlags) {
		let mode = ModifierTouchBarMode(flags: flags)
		if let controller = controller, controller.mode != mode {
			hide()
		}
		guard controller == nil, mode != pendingMode else {
			return
		}
		cancelPending()
		guard let mode = mode, Preferences[mode.preferenceKey] == true else {
			return
		}
		pendingMode = mode
		pendingInputCount = ModifierTouchBarMonitor.inputCount
		holdTimer = Timer.scheduledTimer(withTimeInterval: ModifierTouchBarMonitor.holdDelay, repeats: false) { [weak self] _ in
			self?.holdDidFinish()
		}
	}

	private func holdDidFinish() {
		guard let mode = pendingMode else {
			return
		}
		defer {
			cancelPending()
		}
		guard ModifierTouchBarMode(flags: NSEvent.modifierFlags) == mode,
			  ModifierTouchBarMonitor.inputCount == pendingInputCount,
			  let controller = present(mode) else {
			return
		}
		self.controller = controller
		visibleKeyCount = ModifierTouchBarMonitor.keyDownCount
		watchTimer = Timer.scheduledTimer(withTimeInterval: ModifierTouchBarMonitor.watchInterval, repeats: true) { [weak self] _ in
			self?.watch()
		}
	}

	/// Backs up `flagsChanged`, which may be missed, and closes the bar as soon as a shortcut is typed.
	private func watch() {
		guard let controller = controller else {
			return
		}
		if !controller.isVisible
			|| ModifierTouchBarMode(flags: NSEvent.modifierFlags) != controller.mode
			|| ModifierTouchBarMonitor.keyDownCount != visibleKeyCount {
			hide()
		}
	}

	private func cancelPending() {
		holdTimer?.invalidate()
		holdTimer = nil
		pendingMode = nil
	}

	private func hide() {
		watchTimer?.invalidate()
		watchTimer = nil
		guard let controller = controller else {
			return
		}
		self.controller = nil
		if controller.isVisible {
			controller.dismiss()
		}
	}
}

extension ModifierTouchBarMode {
	var modifierName: String {
		switch self {
		case .appSwitcher:
			return "command"
		case .controlStrip:
			return "option"
		case .windowLayout:
			return "control"
		}
	}

	var preferenceKey: Preferences.Keys {
		switch self {
		case .appSwitcher:
			return .commandTouchBarEnabled
		case .controlStrip:
			return .optionTouchBarEnabled
		case .windowLayout:
			return .controlTouchBarEnabled
		}
	}
}
