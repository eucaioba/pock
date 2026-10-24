//
//  ModifierTouchBarLayout.swift
//  Pock
//
//  Pure logic shared by the modifier Touch Bars, kept free of Pock types so it can be unit tested.
//

import AppKit

internal enum ModifierTouchBarMode: String, CaseIterable {
	case appSwitcher, controlStrip, windowLayout

	/// Modifiers that, when combined with the trigger, cancel the bar.
	static let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function, .capsLock]

	var modifier: NSEvent.ModifierFlags {
		switch self {
		case .appSwitcher:
			return .command
		case .controlStrip:
			return .option
		case .windowLayout:
			return .control
		}
	}

	/// The mode triggered by holding exactly one of `⌘`, `⌥` or `⌃`. Caps Lock is ignored.
	init?(flags: NSEvent.ModifierFlags) {
		let current = flags.intersection(ModifierTouchBarMode.relevantFlags).subtracting(.capsLock)
		guard let mode = ModifierTouchBarMode.allCases.first(where: { $0.modifier == current }) else {
			return nil
		}
		self = mode
	}
}

internal enum WindowLayout: String, CaseIterable {
	case leftHalf, rightHalf, topHalf, bottomHalf, leftThird, centerThird, rightThird, center, maximize, nextDisplay

	/// Target frame inside `visible`. Both rects use the same coordinate space (top-left origin, as Accessibility does).
	func frame(for current: CGRect, in visible: CGRect) -> CGRect {
		let width = visible.width, height = visible.height
		switch self {
		case .leftHalf:
			return CGRect(x: visible.minX, y: visible.minY, width: (width / 2).rounded(), height: height)
		case .rightHalf:
			let half = (width / 2).rounded()
			return CGRect(x: visible.maxX - half, y: visible.minY, width: half, height: height)
		case .topHalf:
			return CGRect(x: visible.minX, y: visible.minY, width: width, height: (height / 2).rounded())
		case .bottomHalf:
			let half = (height / 2).rounded()
			return CGRect(x: visible.minX, y: visible.maxY - half, width: width, height: half)
		case .leftThird, .centerThird, .rightThird:
			let third = (width / 3).rounded()
			let index: CGFloat = self == .leftThird ? 0 : self == .centerThird ? 1 : 2
			return CGRect(x: visible.minX + third * index, y: visible.minY, width: index == 2 ? width - third * 2 : third, height: height)
		case .center:
			let size = CGSize(width: min(current.width, width), height: min(current.height, height))
			return CGRect(x: (visible.midX - size.width / 2).rounded(), y: (visible.midY - size.height / 2).rounded(),
						  width: size.width, height: size.height)
		case .maximize:
			return visible
		case .nextDisplay:
			return current
		}
	}

	/// Moves `current` from `source` to `destination`, keeping its relative position and size.
	static func moved(_ current: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
		guard source.width > 0, source.height > 0 else {
			return current
		}
		let scaleX = destination.width / source.width, scaleY = destination.height / source.height
		let width = min(destination.width, current.width * scaleX), height = min(destination.height, current.height * scaleY)
		let x = destination.minX + (current.minX - source.minX) * scaleX
		let y = destination.minY + (current.minY - source.minY) * scaleY
		return CGRect(x: min(max(destination.minX, x), destination.maxX - width).rounded(),
					  y: min(max(destination.minY, y), destination.maxY - height).rounded(),
					  width: width.rounded(), height: height.rounded())
	}

	/// Converts an AppKit rect (bottom-left origin) to Accessibility coordinates (top-left origin of the primary display).
	static func accessibilityRect(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
		return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
	}
}

/// Most-recently-used ordering for the app switcher.
internal struct ApplicationOrder {
	private(set) var recent: [pid_t] = []

	mutating func activated(_ pid: pid_t) {
		recent.removeAll(where: { $0 == pid })
		recent.insert(pid, at: 0)
	}

	/// Running apps sorted by recent use; apps never activated keep their launch order at the end.
	func sorted(_ running: [pid_t]) -> [pid_t] {
		let known = recent.filter(running.contains)
		return known + running.filter { !known.contains($0) }
	}
}
