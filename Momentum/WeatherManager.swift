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

/// Manages weather data fetching and caching using WeatherKit
@Observable
class WeatherManager: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()
    
    private let weatherService = WeatherService.shared
    private let locationManager = CLLocationManager()
    
    var currentWeather: CurrentWeather?
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
        
        requestLocationPermission()
    }
    
    /// Force fetch current weather
    func forceRefreshWeather() {
        lastUpdate = nil
        currentWeather = nil
        requestLocationPermission()
    }
    
    private func fetchWeather(for location: CLLocation) async {
        isLoading = true
        error = nil
        
        do {
            let weather = try await weatherService.weather(for: location)
            await MainActor.run {
                self.currentWeather = weather.currentWeather
                self.currentLocation = location
                self.lastUpdate = Date()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
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
        self.error = error
        isLoading = false
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
    
    /// Check if goal's weather requirements are met
    func meetsGoalWeatherRequirements(_ goal: Goal) -> Bool {
        // Check tag weather conditions
        if let weatherConditions = goal.primaryTag.weatherConditionsTyped,
           !weatherConditions.isEmpty {
            guard matchesAnyCondition(weatherConditions) else { return false }
        }
        
        // Check temperature requirements
        if let minTemp = goal.primaryTag.minTemperature {
            guard temperatureAbove(minTemp) else { return false }
        }
        
        if let maxTemp = goal.primaryTag.maxTemperature {
            guard temperatureBelow(maxTemp) else { return false }
        }
        
        return true
    }
    
    // MARK: - Helper Methods
    
    private func mapToWeatherCondition(_ condition: WeatherKit.WeatherCondition) -> MomentumKit.WeatherCondition {
        // Map WeatherKit conditions to our simplified enum
        let conditionDescription = condition.description.lowercased()
        
        if conditionDescription.contains("clear") {
            return .clear
        } else if conditionDescription.contains("partly") || conditionDescription.contains("mostly clear") {
            return .partlyCloudy
        } else if conditionDescription.contains("cloud") {
            return .cloudy
        } else if conditionDescription.contains("rain") || conditionDescription.contains("drizzle") {
            return .rainy
        } else if conditionDescription.contains("thunder") || conditionDescription.contains("storm") {
            return .stormy
        } else if conditionDescription.contains("snow") || conditionDescription.contains("flurr") || conditionDescription.contains("blizzard") {
            return .snowy
        } else if conditionDescription.contains("fog") || conditionDescription.contains("haze") || conditionDescription.contains("smok") {
            return .foggy
        } else {
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
            return ["sunshine", "yellow", "lemon", "coral", "sky_blue"]
        case .partlyCloudy:
            return ["sky_blue", "cyan", "mint", "seafoam"]
        case .cloudy:
            return ["grey_blue", "silver0", "slate", "beige"]
        case .rainy:
            return ["teal", "cyan", "grey_blue", "slate", "beige"]
        case .snowy:
            return ["cyan", "sky_blue", "silver0", "mint_blue"]
        case .stormy:
            return ["grey_blue", "navy", "charcoal", "indigo"]
        case .foggy:
            return ["silver0", "beige", "taupe", "sage"]
        }
    }
    
    /// Get theme preset for current weather
    func themeForCurrentWeather() -> ThemePreset? {
        let themes = suggestedThemes()
        guard let firstTheme = themes.first else { return nil }
        return themePresets.first { $0.id == firstTheme }
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
