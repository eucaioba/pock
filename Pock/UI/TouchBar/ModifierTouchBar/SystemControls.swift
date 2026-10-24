//
//  SystemControls.swift
//  Pock
//
//  Volume, brightness and window placement used by the modifier Touch Bars.
//  Values are changed directly instead of posting media keys, which would open
//  System Settings while `⌥` is held.
//

import AppKit
import ApplicationServices
import CoreAudio

internal enum SystemVolume {
	/// `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`, spelled out to support macOS 10.15.
	private static let virtualMainVolume = AudioObjectPropertySelector(0x766D_7663) // 'vmvc'
	static let step: Float = 1 / 16

	private static var outputDevice: AudioDeviceID? {
		var device = AudioDeviceID(0)
		var size = UInt32(MemoryLayout<AudioDeviceID>.size)
		var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
												 mScope: kAudioObjectPropertyScopeGlobal,
												 mElement: 0)
		guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
			  device != 0 else {
			return nil
		}
		return device
	}

	private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
		return AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: 0)
	}

	static var level: Float? {
		guard let device = outputDevice else {
			return nil
		}
		var value = Float32(0)
		var size = UInt32(MemoryLayout<Float32>.size)
		var property = address(virtualMainVolume)
		guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr else {
			return nil
		}
		return value
	}

	static func setLevel(_ level: Float) {
		guard let device = outputDevice else {
			return
		}
		var value = Float32(min(1, max(0, level)))
		var property = address(virtualMainVolume)
		AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
		if value > 0, isMuted {
			setMuted(false)
		}
	}

	static func change(by delta: Float) {
		guard let current = level else {
			return
		}
		setLevel(((current + delta) / step).rounded() * step)
	}

	static var isMuted: Bool {
		guard let device = outputDevice else {
			return false
		}
		var value = UInt32(0)
		var size = UInt32(MemoryLayout<UInt32>.size)
		var property = address(kAudioDevicePropertyMute)
		guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr else {
			return false
		}
		return value != 0
	}

	static func setMuted(_ muted: Bool) {
		guard let device = outputDevice else {
			return
		}
		var value = UInt32(muted ? 1 : 0)
		var property = address(kAudioDevicePropertyMute)
		AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
	}
}

internal enum DisplayBrightness {
	private typealias Getter = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
	private typealias Setter = @convention(c) (CGDirectDisplayID, Float) -> Int32
	static let step: Float = 1 / 16

	private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
	private static let getter: Getter? = symbol("DisplayServicesGetBrightness")
	private static let setter: Setter? = symbol("DisplayServicesSetBrightness")

	private static func symbol<T>(_ name: String) -> T? {
		guard let handle = handle, let pointer = dlsym(handle, name) else {
			return nil
		}
		return unsafeBitCast(pointer, to: T.self)
	}

	private static var builtInDisplay: CGDirectDisplayID? {
		var count = UInt32(0)
		guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
			return nil
		}
		var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
		guard CGGetOnlineDisplayList(count, &displays, &count) == .success else {
			return nil
		}
		return displays.first(where: { CGDisplayIsBuiltin($0) != 0 })
	}

	static var level: Float? {
		guard let getter = getter, let display = builtInDisplay else {
			return nil
		}
		var value = Float(0)
		return getter(display, &value) == 0 ? value : nil
	}

	static func change(by delta: Float) {
		guard let setter = setter, let display = builtInDisplay, let current = level else {
			return
		}
		_ = setter(display, min(1, max(0, ((current + delta) / step).rounded() * step)))
	}
}

internal enum WindowManager {
	static var isTrusted: Bool {
		return AXIsProcessTrusted()
	}

	static func requestAccess() {
		let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
		_ = AXIsProcessTrustedWithOptions(options)
	}

	/// Moves the focused window of the frontmost app. Returns `false` when there is no movable window.
	@discardableResult
	static func apply(_ layout: WindowLayout) -> Bool {
		guard isTrusted,
			  let app = NSWorkspace.shared.frontmostApplication,
			  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
			  let window = focusedWindow(of: app.processIdentifier),
			  let current = frame(of: window),
			  let primaryHeight = NSScreen.screens.first?.frame.height else {
			return false
		}
		let screens = NSScreen.screens.map {
			(frame: WindowLayout.accessibilityRect($0.frame, primaryHeight: primaryHeight),
			 visible: WindowLayout.accessibilityRect($0.visibleFrame, primaryHeight: primaryHeight))
		}
		guard let index = screens.indices.max(by: {
			area(screens[$0].frame.intersection(current)) < area(screens[$1].frame.intersection(current))
		}) else {
			return false
		}
		let target: CGRect
		if layout == .nextDisplay {
			guard screens.count > 1 else {
				return false
			}
			target = WindowLayout.moved(current, from: screens[index].visible, to: screens[(index + 1) % screens.count].visible)
		} else {
			target = layout.frame(for: current, in: screens[index].visible)
		}
		// Size first so the move is not clamped by the old size, then size again once on the destination display.
		set(size: target.size, of: window)
		set(origin: target.origin, of: window)
		set(size: target.size, of: window)
		return true
	}

	private static func area(_ rect: CGRect) -> CGFloat {
		return rect.isNull ? 0 : rect.width * rect.height
	}

	private static func focusedWindow(of pid: pid_t) -> AXUIElement? {
		var value: CFTypeRef?
		guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &value) == .success,
			  let window = value, CFGetTypeID(window) == AXUIElementGetTypeID() else {
			return nil
		}
		return (window as! AXUIElement) // swiftlint:disable:this force_cast
	}

	private static func frame(of window: AXUIElement) -> CGRect? {
		var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
		var origin = CGPoint.zero, size = CGSize.zero
		guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
			  AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
			  let position = positionValue, let extent = sizeValue,
			  AXValueGetValue(position as! AXValue, .cgPoint, &origin), // swiftlint:disable:this force_cast
			  AXValueGetValue(extent as! AXValue, .cgSize, &size) else { // swiftlint:disable:this force_cast
			return nil
		}
		return CGRect(origin: origin, size: size)
	}

	private static func set(origin: CGPoint, of window: AXUIElement) {
		var point = origin
		if let value = AXValueCreate(.cgPoint, &point) {
			AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
		}
	}

	private static func set(size: CGSize, of window: AXUIElement) {
		var extent = size
		if let value = AXValueCreate(.cgSize, &extent) {
			AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
		}
	}
}
