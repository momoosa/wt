//
//  WeatherManager.swift
//  Momentum
//
//  Created by Assistant on 06/03/2026.
//

import Foundation
import WeatherKit
import CoreLocation
import SwiftUI
import MomentumKit

/// Protocol for weather data access — enables mocking for tests
protocol WeatherProviding: AnyObject {
    var currentWeather: CurrentWeather? { get }
    var hourlyForecast: [HourWeather] { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    var weatherDisplayString: String { get }
    
    func refreshWeatherIfNeeded()
    func forceRefreshWeather()
    func matchesAnyCondition(_ conditions: [MomentumKit.WeatherCondition]) -> Bool
    func temperatureAbove(_ minimum: Double) -> Bool
    func temperatureBelow(_ maximum: Double) -> Bool
    func windSpeedBelow(_ maximum: Double) -> Bool
    func forecastCondition(at date: Date) -> MomentumKit.WeatherCondition?
    func forecastTemperature(at date: Date) -> Double?
}

/// Manages weather data fetching and caching using WeatherKit
@Observable
class WeatherManager: NSObject, CLLocationManagerDelegate, WeatherProviding {
    static let shared = WeatherManager()
    
    private let weatherService = WeatherService.shared
    private let locationManager = CLLocationManager()
    
    var currentWeather: CurrentWeather?
    var hourlyForecast: [HourWeather] = []
    var currentLocation: CLLocation?
    var lastUpdate: Date?
    var isLoading = false
    var error: Error?
    
    // Cache duration: 30 minutes
    private let cacheDuration: TimeInterval = 30 * 60
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    /// Request location permission and start fetching weather
    func requestLocationPermission() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            error = WeatherError.locationPermissionDenied
        @unknown default:
            break
        }
    }
    
    /// Fetch current weather if cache is stale
    func refreshWeatherIfNeeded() {
        // Check if we need to refresh
        if let lastUpdate = lastUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheDuration,
           currentWeather != nil {
            return
        }
        
        // If we had an error, wait a bit before retrying
        if let lastUpdate = lastUpdate,
           error != nil,
           Date().timeIntervalSince(lastUpdate) < 60 { // Wait at least 1 minute between retries
            return
        }
        
        requestLocationPermission()
    }
    
    /// Force fetch current weather
    func forceRefreshWeather() {
        lastUpdate = nil
        currentWeather = nil
        requestLocationPermission()
    }
    
    private func fetchWeather(for location: CLLocation) async {
        await MainActor.run {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isLoading = true
                error = nil
            }
        }
        
        do {
            let (current, hourly) = try await weatherService.weather(
                for: location,
                including: .current, .hourly
            )
            await MainActor.run {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.currentWeather = current
                    self.hourlyForecast = Array(hourly)
                    self.currentLocation = location
                    self.lastUpdate = Date()
                    self.isLoading = false
                }
                print("✅ WeatherKit: Fetched current + \(hourly.count)h forecast")
            }
        } catch {
            await MainActor.run {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.error = error
                    self.isLoading = false
                }
                
                print("❌ WeatherKit Error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Domain: \(nsError.domain)")
                    print("   Code: \(nsError.code)")
                    print("   UserInfo: \(nsError.userInfo)")
                }
                
                #if targetEnvironment(simulator)
                print("⚠️  Running on simulator - WeatherKit may not work properly")
                print("   Try running on a physical device for better results")
                #endif
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task {
            await fetchWeather(for: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.error = error
            isLoading = false
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }
    
    // MARK: - Weather Condition Mapping
    
    /// Convert WeatherKit condition to app's WeatherCondition enum
    func getCurrentCondition() -> MomentumKit.WeatherCondition? {
        guard let weather = currentWeather else { return nil }
        return mapToWeatherCondition(weather.condition)
    }
    
    /// Get current temperature in Celsius
    func getCurrentTemperature() -> Double? {
        return currentWeather?.temperature.value
    }
    
    /// Get current wind speed in km/h
    func getCurrentWindSpeed() -> Double? {
        guard let weather = currentWeather else { return nil }
        return weather.wind.speed.converted(to: .kilometersPerHour).value
    }
    
    /// Check if current weather matches the given condition
    func matchesCondition(_ condition: MomentumKit.WeatherCondition) -> Bool {
        guard let currentCondition = getCurrentCondition() else { return false }
        return currentCondition == condition
    }
    
    /// Check if current weather matches any of the given conditions
    func matchesAnyCondition(_ conditions: [MomentumKit.WeatherCondition]) -> Bool {
        guard let currentCondition = getCurrentCondition() else { return false }
        return conditions.contains(currentCondition)
    }
    
    /// Check if current temperature is within range
    func temperatureInRange(_ range: ClosedRange<Double>) -> Bool {
        guard let temp = getCurrentTemperature() else { return false }
        return range.contains(temp)
    }
    
    /// Check if current temperature meets minimum requirement
    func temperatureAbove(_ minimum: Double) -> Bool {
        guard let temp = getCurrentTemperature() else { return false }
        return temp >= minimum
    }
    
    /// Check if current temperature meets maximum requirement
    func temperatureBelow(_ maximum: Double) -> Bool {
        guard let temp = getCurrentTemperature() else { return false }
        return temp <= maximum
    }
    
    /// Check if current wind speed is at or below the maximum (km/h)
    func windSpeedBelow(_ maximum: Double) -> Bool {
        guard let speed = getCurrentWindSpeed() else { return false }
        return speed <= maximum
    }
    
    // MARK: - Hourly Forecast Lookup
    
    /// Find the nearest hourly forecast entry for a given date
    private func nearestForecast(for date: Date) -> HourWeather? {
        hourlyForecast.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }
    
    /// Get the forecast weather condition at a specific time
    func forecastCondition(at date: Date) -> MomentumKit.WeatherCondition? {
        guard let hour = nearestForecast(for: date) else { return nil }
        return mapToWeatherCondition(hour.condition)
    }
    
    /// Get the forecast temperature (Celsius) at a specific time
    func forecastTemperature(at date: Date) -> Double? {
        nearestForecast(for: date)?.temperature.value
    }
    
    /// Check if goal's weather requirements are met
    func meetsGoalWeatherRequirements(_ goal: Goal) -> Bool {
        // Check tag weather conditions
        if let weatherConditions = goal.primaryTag?.weatherConditionsTyped,
           !weatherConditions.isEmpty {
            guard matchesAnyCondition(weatherConditions) else { return false }
        }
        
        // Check temperature requirements
        if let minTemp = goal.primaryTag?.minTemperature {
            guard temperatureAbove(minTemp) else { return false }
        }
        
        if let maxTemp = goal.primaryTag?.maxTemperature {
            guard temperatureBelow(maxTemp) else { return false }
        }
        
        return true
    }
    
    // MARK: - Helper Methods
    
    private func mapToWeatherCondition(_ condition: WeatherKit.WeatherCondition) -> MomentumKit.WeatherCondition {
        switch condition {
        // Clear
        case .clear, .hot:
            return .clear
        // Partly cloudy
        case .mostlyClear, .partlyCloudy, .breezy, .windy, .sunShowers, .sunFlurries:
            return .partlyCloudy
        // Cloudy
        case .cloudy, .mostlyCloudy, .blowingDust:
            return .cloudy
        // Rainy
        case .drizzle, .rain, .heavyRain, .freezingDrizzle, .freezingRain, .hail, .sleet, .wintryMix:
            return .rainy
        // Stormy
        case .thunderstorms, .strongStorms, .isolatedThunderstorms, .scatteredThunderstorms, .hurricane, .tropicalStorm:
            return .stormy
        // Snowy
        case .snow, .heavySnow, .flurries, .blizzard, .blowingSnow, .frigid:
            return .snowy
        // Foggy
        case .foggy, .haze, .smoky:
            return .foggy
        @unknown default:
            return .clear
        }
    }
}

// MARK: - Weather Error

enum WeatherError: LocalizedError {
    case locationPermissionDenied
    case weatherDataUnavailable
    
    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "Location permission is required to fetch weather data"
        case .weatherDataUnavailable:
            return "Weather data is currently unavailable"
        }
    }
}

// MARK: - Weather Theme Suggestions

extension WeatherManager {
    /// Get theme suggestions based on current weather
    func suggestedThemes() -> [String] {
        guard let condition = getCurrentCondition() else { return [] }
        
        switch condition {
        case .clear:
            return ["palette_04", "palette_08", "palette_12", "palette_17"]
        case .partlyCloudy:
            return ["palette_17", "palette_03", "palette_10"]
        case .cloudy:
            return ["palette_18", "palette_20"]
        case .rainy:
            return ["palette_03", "palette_18", "palette_20"]
        case .snowy:
            return ["palette_03", "palette_17", "palette_18"]
        case .stormy:
            return ["palette_18", "palette_16"]
        case .foggy:
            return ["palette_18", "palette_20", "palette_19"]
        }
    }
    
    /// Get theme preset for current weather
    func themeForCurrentWeather() -> ThemePreset? {
        let themes = suggestedThemes()
        guard let firstTheme = themes.first else { return nil }
        return ThemeStore.presets.first { $0.id == firstTheme }
    }
}

// MARK: - Weather Display Helpers

extension WeatherManager {
    /// Get display string for current weather
    var weatherDisplayString: String {
        guard let condition = getCurrentCondition(),
              let temp = getCurrentTemperature() else {
            return "Weather unavailable"
        }
        
        let tempString = String(format: "%.0f°C", temp)
        return "\(condition.displayName), \(tempString)"
    }
    
    /// Get icon for current weather
    var weatherIcon: String {
        guard let condition = getCurrentCondition() else {
            return "cloud.fill"
        }
        return condition.icon
    }
}
