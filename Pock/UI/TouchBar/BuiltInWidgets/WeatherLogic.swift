//
//  WeatherLogic.swift
//  Pock
//
//  Parsing and formatting for the Weather item, kept free of AppKit so it can be unit tested.
//

import Foundation

internal struct WeatherPlace: Equatable {
	let name: String
	let region: String?
	let country: String?
	let latitude: Double
	let longitude: Double

	var displayName: String {
		return [name, region, country].compactMap { $0 }.reduce(into: [String]()) { parts, part in
			if parts.last != part {
				parts.append(part)
			}
		}.joined(separator: ", ")
	}
}

internal struct WeatherHour: Equatable {
	let time: String
	let temperature: Double
	let code: Int
	let isDay: Bool
}

internal struct WeatherReport: Equatable {
	let temperature: Double
	let apparentTemperature: Double
	let code: Int
	let isDay: Bool
	let high: Double?
	let low: Double?
	let rainChance: Int?
	let hours: [WeatherHour]
}

internal enum WeatherLogic {

	static func forecastURL(for place: WeatherPlace, fahrenheit: Bool) -> URL? {
		var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
		components?.queryItems = [
			URLQueryItem(name: "latitude", value: String(place.latitude)),
			URLQueryItem(name: "longitude", value: String(place.longitude)),
			URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
			URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day"),
			URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
			URLQueryItem(name: "forecast_hours", value: "7"),
			URLQueryItem(name: "forecast_days", value: "1"),
			URLQueryItem(name: "timezone", value: "auto"),
			URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius")
		]
		return components?.url
	}

	static func geocodingURL(for query: String) -> URL? {
		var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
		components?.queryItems = [
			URLQueryItem(name: "name", value: query),
			URLQueryItem(name: "count", value: "6"),
			URLQueryItem(name: "format", value: "json")
		]
		return components?.url
	}

	static func parseReport(_ data: Data) -> WeatherReport? {
		struct Response: Decodable {
			struct Current: Decodable {
				let temperature_2m: Double
				let apparent_temperature: Double?
				let weather_code: Int
				let is_day: Int
			}
			struct Hourly: Decodable {
				let time: [String]
				let temperature_2m: [Double?]
				let weather_code: [Int?]
				let is_day: [Int?]
			}
			struct Daily: Decodable {
				let temperature_2m_max: [Double?]
				let temperature_2m_min: [Double?]
				let precipitation_probability_max: [Int?]?
			}
			let current: Current
			let hourly: Hourly?
			let daily: Daily?
		}
		guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
			return nil
		}
		var hours: [WeatherHour] = []
		if let hourly = response.hourly {
			for (index, time) in hourly.time.enumerated() {
				guard index < hourly.temperature_2m.count, let temperature = hourly.temperature_2m[index],
					  index < hourly.weather_code.count, let code = hourly.weather_code[index] else {
					continue
				}
				let isDay = index < hourly.is_day.count ? (hourly.is_day[index] ?? 1) == 1 : true
				hours.append(WeatherHour(time: time, temperature: temperature, code: code, isDay: isDay))
			}
		}
		return WeatherReport(temperature: response.current.temperature_2m,
							 apparentTemperature: response.current.apparent_temperature ?? response.current.temperature_2m,
							 code: response.current.weather_code,
							 isDay: response.current.is_day == 1,
							 high: response.daily?.temperature_2m_max.first ?? nil,
							 low: response.daily?.temperature_2m_min.first ?? nil,
							 rainChance: response.daily?.precipitation_probability_max?.first ?? nil,
							 hours: hours)
	}

	static func parsePlaces(_ data: Data) -> [WeatherPlace] {
		struct Response: Decodable {
			struct Result: Decodable {
				let name: String
				let latitude: Double
				let longitude: Double
				let country: String?
				let admin1: String?
			}
			let results: [Result]?
		}
		guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
			return []
		}
		return (response.results ?? []).map {
			WeatherPlace(name: $0.name, region: $0.admin1, country: $0.country, latitude: $0.latitude, longitude: $0.longitude)
		}
	}

	/// City from an IANA time zone, e.g. "America/Sao_Paulo" -> "Sao Paulo". Nil for zones that name no city.
	static func cityName(fromTimeZone identifier: String) -> String? {
		let parts = identifier.split(separator: "/")
		guard parts.count >= 2, let last = parts.last, !["Etc", "GMT", "UTC"].contains(String(parts[0])) else {
			return nil
		}
		return last.replacingOccurrences(of: "_", with: " ")
	}

	/// Localization key suffix for a WMO weather code.
	static func conditionKey(code: Int) -> String {
		switch code {
		case 0:
			return "clear"
		case 1:
			return "mainly-clear"
		case 2:
			return "partly-cloudy"
		case 3:
			return "overcast"
		case 45, 48:
			return "fog"
		case 51, 53, 55, 56, 57:
			return "drizzle"
		case 61, 63, 65, 66, 67:
			return "rain"
		case 80, 81, 82:
			return "showers"
		case 71, 73, 75, 77, 85, 86:
			return "snow"
		case 95, 96, 99:
			return "thunderstorm"
		default:
			return "unknown"
		}
	}

	static func symbol(code: Int, isDay: Bool) -> String {
		switch conditionKey(code: code) {
		case "clear":
			return isDay ? "sun.max.fill" : "moon.stars.fill"
		case "mainly-clear", "partly-cloudy":
			return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
		case "overcast":
			return "cloud.fill"
		case "fog":
			return "cloud.fog.fill"
		case "drizzle":
			return "cloud.drizzle.fill"
		case "rain", "showers":
			return "cloud.rain.fill"
		case "snow":
			return "cloud.snow.fill"
		case "thunderstorm":
			return "cloud.bolt.rain.fill"
		default:
			return "cloud.fill"
		}
	}

	static func temperatureText(_ value: Double) -> String {
		let rounded = Int(value.rounded())
		return "\(rounded == 0 ? 0 : rounded)°"
	}

	/// "10:00" from an Open-Meteo local time such as "2026-10-24T10:00".
	static func hourLabel(_ time: String) -> String {
		return time.split(separator: "T").last.map(String.init) ?? time
	}
}
