//
//  KeyboardShortcutSender.swift
//  Pock
//
//  Sends a keyboard shortcut to the frontmost app. Characters are mapped to key codes
//  through the current keyboard layout, so "cmd+[" works on ABNT2, AZERTY and other layouts.
//

import AppKit
import Carbon.HIToolbox

internal enum KeyboardShortcutSender {

	/// Posting keyboard events to another process requires Accessibility trust.
	@discardableResult
	static func send(_ shortcut: KeyboardShortcut, to app: NSRunningApplication) -> Bool {
		guard AXIsProcessTrusted(), let resolved = resolve(shortcut) else {
			return false
		}
		var flags = CGEventFlags(rawValue: 0)
		let modifiers = shortcut.modifiers.union(resolved.extraModifiers)
		if modifiers.contains(.command) { flags.insert(.maskCommand) }
		if modifiers.contains(.shift) { flags.insert(.maskShift) }
		if modifiers.contains(.option) { flags.insert(.maskAlternate) }
		if modifiers.contains(.control) { flags.insert(.maskControl) }
		let source = CGEventSource(stateID: .privateState)
		guard let down = CGEvent(keyboardEventSource: source, virtualKey: resolved.code, keyDown: true),
			  let up = CGEvent(keyboardEventSource: source, virtualKey: resolved.code, keyDown: false) else {
			return false
		}
		down.flags = flags
		up.flags = flags
		down.postToPid(app.processIdentifier)
		up.postToPid(app.processIdentifier)
		return true
	}

	private static func resolve(_ shortcut: KeyboardShortcut) -> (code: CGKeyCode, extraModifiers: NSEvent.ModifierFlags)? {
		switch shortcut.key {
		case .code(let code):
			return (code, [])
		case .character(let character):
			return keyCode(for: character)
		}
	}

	/// Finds the key that types `character` on the current layout, without or with Shift/Option.
	private static func keyCode(for character: Character) -> (code: CGKeyCode, extraModifiers: NSEvent.ModifierFlags)? {
		guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
				?? TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
			  let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
			return nil
		}
		let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
		let target = String(character)
		let candidates: [(state: UInt32, modifiers: NSEvent.ModifierFlags)] = [
			(0, []), (UInt32(shiftKey >> 8), .shift), (UInt32(optionKey >> 8), .option)
		]
		return data.withUnsafeBytes { buffer -> (CGKeyCode, NSEvent.ModifierFlags)? in
			guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
				return nil
			}
			for candidate in candidates {
				for code in 0..<UInt16(128) {
					var deadKeyState: UInt32 = 0
					var length = 0
					var characters = [UniChar](repeating: 0, count: 4)
					let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), candidate.state,
												UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
												&deadKeyState, characters.count, &length, &characters)
					if status == noErr, length > 0,
					   String(utf16CodeUnits: characters, count: length).lowercased() == target {
						return (CGKeyCode(code), candidate.modifiers)
					}
				}
			}
			return nil
		}
	}
}
