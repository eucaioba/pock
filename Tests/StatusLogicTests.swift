import Foundation

@main struct StatusLogicTests {
	static func main() {
		precondition(StatusLogic.batterySymbol(percent: 5, charging: false, pluggedIn: false) == "battery.0percent")
		precondition(StatusLogic.batterySymbol(percent: 30, charging: false, pluggedIn: false) == "battery.25percent")
		precondition(StatusLogic.batterySymbol(percent: 62, charging: false, pluggedIn: false) == "battery.50percent")
		precondition(StatusLogic.batterySymbol(percent: 90, charging: false, pluggedIn: false) == "battery.100percent")
		precondition(StatusLogic.batterySymbol(percent: 40, charging: true, pluggedIn: true) == "battery.100percent.bolt")
		precondition(StatusLogic.batterySymbol(percent: 100, charging: false, pluggedIn: true) == "battery.100percent.bolt")
		precondition(StatusLogic.batterySymbol(percent: 95, charging: false, pluggedIn: true) == "battery.100percent")

		precondition(StatusLogic.wifiBars(rssi: 0) == 0)
		precondition(StatusLogic.wifiBars(rssi: -85) == 1)
		precondition(StatusLogic.wifiBars(rssi: -70) == 2)
		precondition(StatusLogic.wifiBars(rssi: -41) == 3)

		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "UTC")!
		let now = Date(timeIntervalSince1970: 1_800_000_000 + 15.25) // hh:mm:15.25
		let seconds = calendar.component(.second, from: now)
		precondition(abs(StatusLogic.clockDelay(format: "HH:mm", now: now, calendar: calendar) - (60 - Double(seconds) - 0.25)) < 0.001)
		precondition(abs(StatusLogic.clockDelay(format: "HH:mm:ss", now: now, calendar: calendar) - 0.75) < 0.001)
		// Quoted literals do not count as a seconds field.
		precondition(StatusLogic.clockDelay(format: "'Days' HH:mm", now: now, calendar: calendar) > 1)

		precondition(StatusLogic.inputSourceLabel(languages: ["pt"], name: "Brazilian - Pro") == "PT")
		precondition(StatusLogic.inputSourceLabel(languages: ["zh-Hans", "en"], name: "Pinyin") == "ZH")
		precondition(StatusLogic.inputSourceLabel(languages: [], name: "Unicode Hex Input") == "UN")
		print("PASS battery symbols, Wi-Fi bars, clock timing and input source labels")
	}
}
