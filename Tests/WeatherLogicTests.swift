import Foundation

@main struct WeatherLogicTests {
	static func main() {
		let forecast = #"{"latitude":-23.51,"longitude":-46.61,"timezone":"America/Sao_Paulo","current":{"time":"2026-10-24T10:00","interval":900,"temperature_2m":23.1,"apparent_temperature":24.4,"weather_code":3,"is_day":1},"hourly":{"time":["2026-10-24T10:00","2026-10-24T11:00","2026-10-24T12:00"],"temperature_2m":[23.1,24.6,null],"weather_code":[51,3,3],"is_day":[1,1,1]},"daily":{"time":["2026-10-24"],"temperature_2m_max":[25.0],"temperature_2m_min":[17.1],"precipitation_probability_max":[49]}}"#
		guard let report = WeatherLogic.parseReport(Data(forecast.utf8)) else {
			preconditionFailure("forecast did not parse")
		}
		precondition(report.temperature == 23.1 && report.apparentTemperature == 24.4 && report.code == 3 && report.isDay)
		precondition(report.high == 25.0 && report.low == 17.1 && report.rainChance == 49)
		// A null hour is skipped instead of failing the whole report.
		precondition(report.hours.count == 2 && report.hours[1].temperature == 24.6)
		let minimal = #"{"current":{"temperature_2m":-3.4,"weather_code":71,"is_day":0}}"#
		let cold = WeatherLogic.parseReport(Data(minimal.utf8))
		precondition(cold?.apparentTemperature == -3.4 && cold?.high == nil && cold?.hours.isEmpty == true)
		precondition(WeatherLogic.parseReport(Data("{}".utf8)) == nil && WeatherLogic.parseReport(Data("nope".utf8)) == nil)

		let places = #"{"results":[{"id":1,"name":"São Paulo","latitude":-23.5475,"longitude":-46.63611,"country":"Brazil","admin1":"São Paulo"},{"name":"Frei Paulo","latitude":-10.5,"longitude":-37.5,"country":"Brazil","admin1":"Sergipe"}]}"#
		let parsed = WeatherLogic.parsePlaces(Data(places.utf8))
		precondition(parsed.count == 2 && parsed[0].latitude == -23.5475)
		// "São Paulo, São Paulo, Brazil" collapses the repeated name.
		precondition(parsed[0].displayName == "São Paulo, Brazil" && parsed[1].displayName == "Frei Paulo, Sergipe, Brazil")
		precondition(WeatherLogic.parsePlaces(Data(#"{"generationtime_ms":0.5}"#.utf8)).isEmpty)

		precondition(WeatherLogic.cityName(fromTimeZone: "America/Sao_Paulo") == "Sao Paulo")
		precondition(WeatherLogic.cityName(fromTimeZone: "America/Argentina/Buenos_Aires") == "Buenos Aires")
		precondition(WeatherLogic.cityName(fromTimeZone: "Europe/Amsterdam") == "Amsterdam")
		precondition(WeatherLogic.cityName(fromTimeZone: "UTC") == nil && WeatherLogic.cityName(fromTimeZone: "Etc/GMT+3") == nil)

		precondition(WeatherLogic.symbol(code: 0, isDay: true) == "sun.max.fill" && WeatherLogic.symbol(code: 0, isDay: false) == "moon.stars.fill")
		precondition(WeatherLogic.symbol(code: 2, isDay: false) == "cloud.moon.fill" && WeatherLogic.symbol(code: 95, isDay: true) == "cloud.bolt.rain.fill")
		precondition(WeatherLogic.conditionKey(code: 61) == "rain" && WeatherLogic.conditionKey(code: 999) == "unknown")
		precondition(WeatherLogic.temperatureText(23.6) == "24°" && WeatherLogic.temperatureText(-0.4) == "0°" && WeatherLogic.temperatureText(-3.5) == "-4°")
		precondition(WeatherLogic.hourLabel("2026-10-24T10:00") == "10:00")

		let place = WeatherPlace(name: "São Paulo", region: nil, country: "Brazil", latitude: -23.5, longitude: -46.6)
		let url = WeatherLogic.forecastURL(for: place, fahrenheit: true)?.absoluteString ?? ""
		precondition(url.contains("temperature_unit=fahrenheit") && url.contains("latitude=-23.5") && url.contains("timezone=auto"))
		precondition(WeatherLogic.geocodingURL(for: "São Paulo")?.absoluteString.contains("name=S%C3%A3o%20Paulo") == true)
		print("PASS forecast and place parsing, time zone city guess, symbols and temperature text")
	}
}
