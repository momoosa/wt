//
//  GoalTag.swift
//  WeektimeKit
//
//  Created by Assistant on 31/01/2026.
//

import Foundation
import SwiftData
import WeatherKit

/// A tag that can be applied to goals, providing both visual theming and smart recommendation triggers
@Model
public final class GoalTag {
    public var title: String
    public private(set) var theme: Theme
    
    // Smart Triggers (optional - nil means no constraint)
    public var weatherConditions: [String]? // WeatherCondition raw values
    public var minTemperature: Double? // Celsius
    public var maxTemperature: Double? // Celsius
    public var timeOfDayPreferences: [String]? // TimeOfDay raw values
    public var locationTypes: [String]? // LocationType raw values
    public var requiresDaylight: Bool = false
    public var isSmart: Bool { // Computed property to check if tag has any triggers
        weatherConditions != nil || minTemperature != nil || maxTemperature != nil || 
        timeOfDayPreferences != nil || locationTypes != nil || requiresDaylight
    }
    
    public init(
        title: String, 
        color: Theme,
        weatherConditions: [WeatherCondition]? = nil,
        temperatureRange: ClosedRange<Double>? = nil,
        timeOfDayPreferences: [TimeOfDay]? = nil,
        locationTypes: [LocationType]? = nil,
        requiresDaylight: Bool = false
    ) {
        self.title = title
        self.theme = color
        self.weatherConditions = weatherConditions?.map { $0.rawValue }
        self.minTemperature = temperatureRange?.lowerBound
        self.maxTemperature = temperatureRange?.upperBound
        self.timeOfDayPreferences = timeOfDayPreferences?.map { $0.rawValue }
        self.locationTypes = locationTypes?.map { $0.rawValue }
        self.requiresDaylight = requiresDaylight
    }
    
    // Convenience accessors for type-safe access
    public var weatherConditionsTyped: [WeatherCondition]? {
        weatherConditions?.compactMap { WeatherCondition(rawValue: $0) }
    }
    
    public var timeOfDayPreferencesTyped: [TimeOfDay]? {
        timeOfDayPreferences?.compactMap { TimeOfDay(rawValue: $0) }
    }
    
    public var locationTypesTyped: [LocationType]? {
        locationTypes?.compactMap { LocationType(rawValue: $0) }
    }
    
    public var temperatureRange: ClosedRange<Double>? {
        guard let min = minTemperature, let max = maxTemperature else { return nil }
        return min...max
    }
    
    // MARK: - Editor-friendly properties
    // These properties match the naming used in ContextTagEditorView
    public var requiresTimesOfDay: [TimeOfDay]? {
        get { timeOfDayPreferencesTyped }
        set { timeOfDayPreferences = newValue?.map { $0.rawValue } }
    }
    
    public var requiresWeatherConditions: [WeatherCondition]? {
        get { weatherConditionsTyped }
        set { weatherConditions = newValue?.map { $0.rawValue } }
    }
    
    public var requiresLocations: [LocationType]? {
        get { locationTypesTyped }
        set { locationTypes = newValue?.map { $0.rawValue } }
    }
    
    public var requiresMinTemperature: Double? {
        get { minTemperature }
        set { minTemperature = newValue }
    }
    
    public var requiresMaxTemperature: Double? {
        get { maxTemperature }
        set { maxTemperature = newValue }
    }
}

// MARK: - Time of Day

public enum TimeOfDay: String, Codable, CaseIterable, Hashable, Comparable {
    case morning
    case midday
    case afternoon
    case evening
    case night
    
    public var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
    
    public var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }
    
    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        let order: [TimeOfDay] = [.morning, .midday, .afternoon, .evening, .night]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Weather Condition

public enum WeatherCondition: String, Codable, CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case rainy
    case snowy
    case stormy
    case foggy
    
    public var displayName: String {
        switch self {
        case .clear: return "Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .rainy: return "Rainy"
        case .snowy: return "Snowy"
        case .stormy: return "Stormy"
        case .foggy: return "Foggy"
        }
    }
    
    public var icon: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .snowy: return "cloud.snow.fill"
        case .stormy: return "cloud.bolt.fill"
        case .foggy: return "cloud.fog.fill"
        }
    }
}

// MARK: - Location Type

public enum LocationType: String, Codable, CaseIterable {
    case anywhere
    case home
    case outdoor
    case gym
    case office
    case commute
    
    public var displayName: String {
        switch self {
        case .anywhere: return "Anywhere"
        case .home: return "Home"
        case .outdoor: return "Outdoors"
        case .gym: return "Gym"
        case .office: return "Office"
        case .commute: return "Commute"
        }
    }
    
    public var icon: String {
        switch self {
        case .anywhere: return "location.fill"
        case .home: return "house.fill"
        case .outdoor: return "tree.fill"
        case .gym: return "dumbbell.fill"
        case .office: return "building.2.fill"
        case .commute: return "car.fill"
        }
    }
}

// MARK: - Predefined Smart Tags

public extension GoalTag {
    /// Predefined smart tags with intelligent triggers
    static func predefinedSmartTags(themes: [Theme]) -> [GoalTag] {
        return [
            // Outdoor activities
            GoalTag(
                title: "Outdoors",
                color: themes.first(where: { $0.id == "green" }) ?? themes[0],
                weatherConditions: [.clear, .partlyCloudy],
                temperatureRange: 10...30, // 50-86°F
                locationTypes: [.outdoor],
                requiresDaylight: true
            ),
            
            // Early morning activities
            GoalTag(
                title: "Early Morning",
                color: themes.first(where: { $0.id == "sunshine" }) ?? themes[0],
                timeOfDayPreferences: [.morning]
            ),
            
            // Cozy indoor activities (perfect for bad weather)
            GoalTag(
                title: "Cozy Indoor",
                color: themes.first(where: { $0.id == "beige" }) ?? themes[0],
                weatherConditions: [.rainy, .snowy, .cloudy],
                locationTypes: [.home]
            ),
            
            // Energizing activities
            GoalTag(
                title: "Energizing",
                color: themes.first(where: { $0.id == "orange" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .midday]
            ),
            
            // Relaxing evening activities
            GoalTag(
                title: "Evening Wind Down",
                color: themes.first(where: { $0.id == "purple" }) ?? themes[0],
                timeOfDayPreferences: [.evening]
            ),
            
            // Cold weather activities
            GoalTag(
                title: "Cold Weather",
                color: themes.first(where: { $0.id == "cyan" }) ?? themes[0],
                weatherConditions: [.snowy],
                temperatureRange: -10...10
            ),
            
            // Warm weather activities
            GoalTag(
                title: "Warm Weather",
                color: themes.first(where: { $0.id == "coral" }) ?? themes[0],
                weatherConditions: [.clear, .partlyCloudy],
                temperatureRange: 20...35
            ),
            
            // Focus work (quiet, daytime)
            GoalTag(
                title: "Focus Time",
                color: themes.first(where: { $0.id == "blue" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .midday, .afternoon],
                locationTypes: [.home, .office]
            ),
            
            // Social activities (flexible timing)
            GoalTag(
                title: "Social",
                color: themes.first(where: { $0.id == "pink0" }) ?? themes[0],
                timeOfDayPreferences: [.afternoon, .evening]
            ),
            
            // Gym workouts
            GoalTag(
                title: "Gym",
                color: themes.first(where: { $0.id == "red" }) ?? themes[0],
                locationTypes: [.gym]
            )
        ]
    }
}
