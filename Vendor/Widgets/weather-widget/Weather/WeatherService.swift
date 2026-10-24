//
//  WeatherService.swift
//  Weather
//
//  Created by Pierluigi Galdi on 20/06/21.
//  Copyright © 2021 Pierluigi Galdi. All rights reserved.
//

import Foundation
import CoreLocation
import AppKit

struct Weather: Codable {
    let name: String
    let temp: Double
    let icon: String
    let description: String
    var temperature: String {
        guard temp > -999 else {
            return "Unknown information"
        }
        let units: String = Preferences[.units]
        switch units {
        case "celsius":
            let converted = (temp - 32) * (5/9)
            return "\(Int(converted))°"
        default:
            return "\(Int(temp))°"
        }
    }
}

struct WeatherData: Codable {
    struct Metadata: Codable {
        let error: String?
        let code: Int
    }
    let metadata: Metadata
    let weather: Weather
    private enum CodingKeys: String, CodingKey {
        case weather = "data", metadata
    }
}

internal class WeatherService {

    /// Open-Meteo current conditions (no API key). The previous weather.navalia.app backend no longer responds.
    private struct Forecast: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
        }
        let current: Current
    }

    /// Maps a WMO weather code to the bundled OpenWeather-style icon name and a description.
    static func condition(forCode code: Int, isDay: Bool) -> (icon: String, description: String) {
        let base: String, description: String
        switch code {
        case 0: (base, description) = ("01", "Clear sky")
        case 1: (base, description) = ("02", "Mainly clear")
        case 2: (base, description) = ("03", "Partly cloudy")
        case 3: (base, description) = ("04", "Overcast")
        case 45, 48: (base, description) = ("50", "Fog")
        case 51, 53, 55, 56, 57: (base, description) = ("09", "Drizzle")
        case 61, 63, 65, 66, 67: (base, description) = ("10", "Rain")
        case 80, 81, 82: (base, description) = ("09", "Rain showers")
        case 71, 73, 75, 77, 85, 86: (base, description) = ("13", "Snow")
        case 95, 96, 99: (base, description) = ("11", "Thunderstorm")
        default: (base, description) = ("03", "Unknown conditions")
        }
        return (base + (isDay ? "d" : "n"), description)
    }

    private static func unavailable() -> WeatherData {
        let name: String = Preferences[.city_name]
        return WeatherData(
            metadata: .init(error: nil, code: -999),
            weather: Weather(name: name, temp: -999, icon: NSImage.touchBarSearchTemplateName, description: "Unknown information")
        )
    }

    func currentConditions(for coordinate: CLLocationCoordinate2D, cityName: String, result: @escaping (WeatherData?) -> Void) {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit")
        ]
        guard let url = components.url else {
            result(WeatherService.unavailable())
            return
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let session = URLSession.shared.dataTask(with: request) { [result] data, response, error in
            print("[WeatherService]: \((response as? HTTPURLResponse)?.statusCode ?? -999)")
            guard error == nil, let data = data,
                  let forecast = try? JSONDecoder().decode(Forecast.self, from: data) else {
                result(WeatherService.unavailable())
                return
            }
            let condition = WeatherService.condition(forCode: forecast.current.weather_code, isDay: forecast.current.is_day == 1)
            result(WeatherData(
                metadata: .init(error: nil, code: 200),
                weather: Weather(name: cityName, temp: forecast.current.temperature_2m,
                                 icon: condition.icon, description: condition.description)
            ))
        }
        session.resume()
    }

}
