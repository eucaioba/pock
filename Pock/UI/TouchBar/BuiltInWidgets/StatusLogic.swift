//
//  StatusLogic.swift
//  Pock
//
//  Pure helpers for the Status item, kept free of Pock types so they can be unit tested.
//

import Foundation

internal enum StatusLogic {

	/// SF Symbol for a battery level (0...100), with a bolt while on power.
	static func batterySymbol(percent: Int, charging: Bool, pluggedIn: Bool) -> String {
		if charging || (pluggedIn && percent >= 100) {
			return "battery.100percent.bolt"
		}
		switch percent {
		case ..<13:
			return "battery.0percent"
		case ..<38:
			return "battery.25percent"
		case ..<63:
			return "battery.50percent"
		case ..<88:
			return "battery.75percent"
		default:
			return "battery.100percent"
		}
	}

	/// Signal bars (0...3) from RSSI in dBm, matching the menu bar's thresholds closely enough.
	static func wifiBars(rssi: Int) -> Int {
		switch rssi {
		case 0:
			return 0
		case ..<(-80):
			return 1
		case ..<(-67):
			return 2
		default:
			return 3
		}
	}

	/// Seconds until the clock text can next change: every second when the format shows seconds.
	static func clockDelay(format: String, now: Date, calendar: Calendar = .current) -> TimeInterval {
		let unquoted = format.components(separatedBy: "'").enumerated().filter { $0.offset % 2 == 0 }.map(\.element).joined()
		if unquoted.contains("s") {
			return 1 - now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
		}
		let second = Double(calendar.component(.second, from: now))
		let fraction = now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
		return 60 - second - fraction
	}

	/// Short label for a keyboard input source, e.g. "PT" for "com.apple.keylayout.Brazilian-Pro".
	static func inputSourceLabel(languages: [String], name: String) -> String {
		if let language = languages.first, let code = language.split(separator: "-").first, !code.isEmpty {
			return code.uppercased()
		}
		return String(name.prefix(2)).uppercased()
	}
}
