//
//  WeatherTouchBarItem.swift
//  Pock
//
//  Built-in replacement for the Weather widget. Conditions come from Open-Meteo (no key); the
//  place is found by name, or guessed from the Mac's time zone until the user picks one.
//

import AppKit
import PockKit

extension NSTouchBarItem.Identifier {
	static let weather = NSTouchBarItem.Identifier("com.pigigaldi.pock.WeatherItem")
}

extension NSNotification.Name {
	static let weatherDidChange = NSNotification.Name("weatherDidChange")
}

internal enum WeatherStore {
	static var place: WeatherPlace? {
		get {
			let name: String = Preferences[.weatherCity]
			guard !name.isEmpty else {
				return nil
			}
			let country: String = Preferences[.weatherCountry]
			let latitude: Double = Preferences[.weatherLatitude]
			let longitude: Double = Preferences[.weatherLongitude]
			return WeatherPlace(name: name, region: nil, country: country.isEmpty ? nil : country, latitude: latitude, longitude: longitude)
		}
		set {
			guard let place = newValue else {
				return
			}
			Preferences[.weatherCity] = place.name
			Preferences[.weatherCountry] = place.country ?? ""
			Preferences[.weatherLatitude] = place.latitude
			Preferences[.weatherLongitude] = place.longitude
		}
	}

	static var usesFahrenheit: Bool {
		return (Preferences[.weatherUnits] as String) == "fahrenheit"
	}

	/// Looks a place up by name; completes on the main queue.
	static func search(_ query: String, completion: @escaping ([WeatherPlace]) -> Void) {
		guard let url = WeatherLogic.geocodingURL(for: query) else {
			completion([])
			return
		}
		URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 15)) { data, _, _ in
			let places = data.map(WeatherLogic.parsePlaces) ?? []
			DispatchQueue.main.async { completion(places) }
		}.resume()
	}

	/// First launch: use the city named by the Mac's time zone so the item works without setup.
	static func resolveDefaultPlace(completion: @escaping (WeatherPlace?) -> Void) {
		guard place == nil, let city = WeatherLogic.cityName(fromTimeZone: TimeZone.current.identifier) else {
			completion(place)
			return
		}
		search(city) { places in
			if let first = places.first {
				place = first
			}
			completion(place)
		}
	}
}

internal final class WeatherTouchBarItem: NSCustomTouchBarItem {

	private let cityLabel = NSTextField(labelWithString: "")
	private let detailLabel = NSTextField(labelWithString: "")
	private let iconView = NSImageView()
	private let stackView = NSStackView()
	private var report: WeatherReport?
	private var refreshTimer: Timer?
	private var fetching = false

	override init(identifier: NSTouchBarItem.Identifier) {
		super.init(identifier: identifier)
		customizationLabel = "Weather"
		cityLabel.font = .systemFont(ofSize: 11, weight: .medium)
		cityLabel.textColor = .secondaryLabelColor
		cityLabel.lineBreakMode = .byTruncatingTail
		detailLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
		detailLabel.lineBreakMode = .byTruncatingTail
		let text = NSStackView(views: [cityLabel, detailLabel])
		text.orientation = .vertical
		text.alignment = .leading
		text.spacing = 0
		iconView.imageScaling = .scaleProportionallyDown
		iconView.widthAnchor.constraint(equalToConstant: 22).isActive = true
		iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true
		stackView.orientation = .horizontal
		stackView.alignment = .centerY
		stackView.spacing = 6
		stackView.addArrangedSubview(iconView)
		stackView.addArrangedSubview(text)
		stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 150).isActive = true
		stackView.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(showDetails)))
		view = stackView
		render()
		NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .weatherDidChange, object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
		refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
			self?.refresh()
		}
		refresh()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		refreshTimer?.invalidate()
		NotificationCenter.default.removeObserver(self)
		NSWorkspace.shared.notificationCenter.removeObserver(self)
	}

	@objc private func refresh() {
		guard !fetching else {
			return
		}
		fetching = true
		WeatherStore.resolveDefaultPlace { [weak self] place in
			guard let self = self, let place = place,
				  let url = WeatherLogic.forecastURL(for: place, fahrenheit: WeatherStore.usesFahrenheit) else {
				self?.fetching = false
				self?.render()
				return
			}
			URLSession.shared.dataTask(with: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)) { data, _, _ in
				let report = data.flatMap(WeatherLogic.parseReport)
				DispatchQueue.main.async {
					self.fetching = false
					// Keep the last good report when the network is down.
					if let report = report {
						self.report = report
					}
					self.render()
				}
			}.resume()
		}
	}

	private func render() {
		cityLabel.stringValue = WeatherStore.place?.name ?? "Weather"
		guard let report = report else {
			detailLabel.stringValue = "–"
			iconView.image = symbol("cloud.fill")
			return
		}
		var text = WeatherLogic.temperatureText(report.temperature)
		if Preferences[.weatherShowDescription] {
			text += " " + "weather.\(WeatherLogic.conditionKey(code: report.code))".localized
		}
		detailLabel.stringValue = text
		iconView.image = symbol(WeatherLogic.symbol(code: report.code, isDay: report.isDay))
	}

	private func symbol(_ name: String) -> NSImage? {
		guard #available(macOS 11.0, *), var image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
			return nil
		}
		if #available(macOS 12.0, *) {
			let configuration = NSImage.SymbolConfiguration(paletteColors: Self.palette(for: name))
			image = image.withSymbolConfiguration(configuration) ?? image
		}
		return image
	}

	@available(macOS 12.0, *)
	private static func palette(for name: String) -> [NSColor] {
		if name.hasPrefix("sun") {
			return [.systemYellow]
		}
		if name.contains("moon") {
			return [.systemIndigo, .white]
		}
		if name.contains("sun") {
			return [.white, .systemYellow]
		}
		if name.contains("bolt") {
			return [.systemYellow, .lightGray, .systemBlue]
		}
		if name.contains("rain") || name.contains("drizzle") {
			return [.systemBlue, .lightGray]
		}
		return [.lightGray, .white]
	}

	@objc private func showDetails() {
		guard let report = report, let navigation = AppController.shared.navigationController else {
			refresh()
			return
		}
		let controller = WeatherDetailController()
		controller.report = report
		controller.placeName = WeatherStore.place?.name ?? ""
		navigation.push(controller)
		controller.scheduleDismiss()
	}
}

/// Today's range, feels-like, rain chance and the next hours, pushed over Pock when the item is tapped.
internal final class WeatherDetailController: PKTouchBarController {

	var report: WeatherReport?
	var placeName = ""
	private var dismissTimer: Timer?

	override func makeTouchBar() -> NSTouchBar? {
		guard let report = report else {
			return nil
		}
		let bar = NSTouchBar()
		var items: [NSTouchBarItem] = []
		func add(_ name: String, _ view: NSView) {
			let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("Pock.Weather.\(name)"))
			item.view = view
			items.append(item)
		}
		let close: NSButton
		if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "general.action.close".localized) {
			close = NSButton(image: image, target: self, action: #selector(closeBar))
		} else {
			close = NSButton(title: "×", target: self, action: #selector(closeBar))
		}
		add("Close", close)

		let title = NSTextField(labelWithString: placeName)
		title.font = .systemFont(ofSize: 13, weight: .semibold)
		var lines = ["weather.\(WeatherLogic.conditionKey(code: report.code))".localized]
		lines.append(String(format: "weather.feels-like".localized, WeatherLogic.temperatureText(report.apparentTemperature)))
		let summary = NSTextField(labelWithString: lines.joined(separator: " · "))
		summary.font = .systemFont(ofSize: 11)
		summary.textColor = .secondaryLabelColor
		let heading = NSStackView(views: [title, summary])
		heading.orientation = .vertical
		heading.alignment = .leading
		heading.spacing = 0
		add("Summary", heading)

		var range: [String] = []
		if let high = report.high, let low = report.low {
			range.append("↑ \(WeatherLogic.temperatureText(high))  ↓ \(WeatherLogic.temperatureText(low))")
		}
		if let chance = report.rainChance {
			range.append(String(format: "weather.rain-chance".localized, chance))
		}
		if !range.isEmpty {
			let label = NSTextField(labelWithString: range.joined(separator: "   "))
			label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
			add("Range", label)
		}

		for (index, hour) in report.hours.prefix(6).enumerated() {
			let time = NSTextField(labelWithString: WeatherLogic.hourLabel(hour.time))
			time.font = .systemFont(ofSize: 10)
			time.textColor = .secondaryLabelColor
			let temperature = NSTextField(labelWithString: WeatherLogic.temperatureText(hour.temperature))
			temperature.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
			let icon = NSImageView()
			if #available(macOS 11.0, *) {
				icon.image = NSImage(systemSymbolName: WeatherLogic.symbol(code: hour.code, isDay: hour.isDay), accessibilityDescription: nil)
			}
			icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
			let row = NSStackView(views: [icon, temperature])
			row.spacing = 3
			let column = NSStackView(views: [time, row])
			column.orientation = .vertical
			column.alignment = .centerX
			column.spacing = 0
			add("Hour\(index)", column)
		}
		bar.templateItems = Set(items)
		bar.defaultItemIdentifiers = items.map(\.identifier)
		return bar
	}

	func scheduleDismiss() {
		dismissTimer?.invalidate()
		dismissTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
			self?.closeBar()
		}
	}

	@objc private func closeBar() {
		dismissTimer?.invalidate()
		dismissTimer = nil
		if isVisible {
			dismiss()
		}
	}
}
