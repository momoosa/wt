//
//  GoalTag.swift
//  MomentumKit
//
//  Created by Assistant on 31/01/2026.
//

import Foundation
import SwiftData
import WeatherKit

/// A tag that can be applied to goals, providing both visual theming and smart recommendation triggers
@Model
public final class GoalTag {
    public var title: String = ""
    public var themeID: String = ""
    
    // Inverse relationships for CloudKit
    @Relationship(deleteRule: .nullify, inverse: \Goal.primaryTag)
    public var goalsAsPrimary: [Goal]? = []
    
    @Relationship(deleteRule: .nullify, inverse: \Goal.otherTags)
    public var goalsAsOther: [Goal]? = []
    
    // Computed property to get the theme preset (lightweight)
    public var themePreset: ThemePreset {
        themePresets.first(where: { $0.id == themeID }) ?? themePresets[0]
    }
    
    // Computed property to get the theme (creates instance - use sparingly)
    public var theme: Theme {
        themePreset.toTheme()
    }
    
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
        self.themeID = color.id
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
    
    /// Convert hour (0-23) to TimeOfDay
    public static func from(hour: Int) -> TimeOfDay {
        switch hour {
        case 6..<10: return .morning
        case 10..<14: return .midday
        case 14..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
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
            // MARK: - Fitness & Movement
            
            // Outdoor Running/Walking
            GoalTag(
                title: "Outdoor Cardio",
                color: themes.first(where: { $0.id == "red" }) ?? themes[0],
                weatherConditions: [.clear, .partlyCloudy],
                temperatureRange: 10...28,
                timeOfDayPreferences: [.morning, .afternoon],
                locationTypes: [.outdoor],
                requiresDaylight: true
            ),
            
            // Gym Workouts
            GoalTag(
                title: "Gym Session",
                color: themes.first(where: { $0.id == "red" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .afternoon, .evening],
                locationTypes: [.gym]
            ),
            
            // Home Workouts
            GoalTag(
                title: "Home Fitness",
                color: themes.first(where: { $0.id == "orange" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .evening],
                locationTypes: [.home]
            ),
            
            // Yoga & Stretching
            GoalTag(
                title: "Yoga & Stretch",
                color: themes.first(where: { $0.id == "mint" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .evening],
                locationTypes: [.home, .outdoor]
            ),
            
            // Outdoor Activities
            GoalTag(
                title: "Outdoors",
                color: themes.first(where: { $0.id == "green" }) ?? themes[0],
                weatherConditions: [.clear, .partlyCloudy],
                temperatureRange: 10...30,
                locationTypes: [.outdoor],
                requiresDaylight: true
            ),
            
            // MARK: - Mindfulness & Wellness
            
            // Morning Meditation
            GoalTag(
                title: "Morning Meditation",
                color: themes.first(where: { $0.id == "purple" }) ?? themes[0],
                timeOfDayPreferences: [.morning],
                locationTypes: [.home]
            ),
            
            // Evening Meditation
            GoalTag(
                title: "Evening Calm",
                color: themes.first(where: { $0.id == "purple" }) ?? themes[0],
                timeOfDayPreferences: [.evening, .night],
                locationTypes: [.home]
            ),
            
            // Mindfulness Practice
            GoalTag(
                title: "Mindfulness",
                color: themes.first(where: { $0.id == "lilac" }) ?? themes[0],
                locationTypes: [.home, .outdoor]
            ),
            
            // Breathing Exercises
            GoalTag(
                title: "Breathwork",
                color: themes.first(where: { $0.id == "cyan" }) ?? themes[0],
                locationTypes: [.anywhere]
            ),
            
            // MARK: - Creativity & Arts
            
            // Creative Work
            GoalTag(
                title: "Creative Time",
                color: themes.first(where: { $0.id == "pink0" }) ?? themes[0],
                timeOfDayPreferences: [.afternoon, .evening],
                locationTypes: [.home, .office]
            ),
            
            // Music Practice
            GoalTag(
                title: "Music Practice",
                color: themes.first(where: { $0.id == "plum" }) ?? themes[0],
                timeOfDayPreferences: [.afternoon, .evening],
                locationTypes: [.home]
            ),
            
            // Art & Drawing
            GoalTag(
                title: "Art & Drawing",
                color: themes.first(where: { $0.id == "coral" }) ?? themes[0],
                timeOfDayPreferences: [.afternoon, .evening],
                locationTypes: [.home],
                requiresDaylight: true
            ),
            
            // Writing
            GoalTag(
                title: "Writing",
                color: themes.first(where: { $0.id == "beige" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .afternoon],
                locationTypes: [.home, .office]
            ),
            
            // Photography
            GoalTag(
                title: "Photography",
                color: themes.first(where: { $0.id == "gold" }) ?? themes[0],
                weatherConditions: [.clear, .partlyCloudy],
                locationTypes: [.outdoor],
                requiresDaylight: true
            ),
            
            // MARK: - Learning & Reading
            
            // Reading
            GoalTag(
                title: "Reading",
                color: themes.first(where: { $0.id == "blue" }) ?? themes[0],
                timeOfDayPreferences: [.evening, .night],
                locationTypes: [.home]
            ),
            
            // Language Learning
            GoalTag(
                title: "Language Learning",
                color: themes.first(where: { $0.id == "sky_blue" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .afternoon],
                locationTypes: [.home, .commute]
            ),
            
            // Study & Focus
            GoalTag(
                title: "Study Time",
                color: themes.first(where: { $0.id == "grey_blue" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .midday, .afternoon],
                locationTypes: [.home, .office]
            ),
            
            // Online Courses
            GoalTag(
                title: "Online Learning",
                color: themes.first(where: { $0.id == "teal" }) ?? themes[0],
                timeOfDayPreferences: [.afternoon, .evening],
                locationTypes: [.home]
            ),
            
            // MARK: - Productivity & Work
            
            // Deep Work
            GoalTag(
                title: "Deep Work",
                color: themes.first(where: { $0.id == "blue" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .midday],
                locationTypes: [.home, .office]
            ),
            
            // Quick Tasks
            GoalTag(
                title: "Quick Tasks",
                color: themes.first(where: { $0.id == "cyan" }) ?? themes[0],
                timeOfDayPreferences: [.midday, .afternoon],
                locationTypes: [.home, .office]
            ),
            
            // Planning & Organization
            GoalTag(
                title: "Planning",
                color: themes.first(where: { $0.id == "mint_blue" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .evening],
                locationTypes: [.home, .office]
            ),
            
            // Email & Communication
            GoalTag(
                title: "Communication",
                color: themes.first(where: { $0.id == "silver0" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .afternoon],
                locationTypes: [.office, .home]
            ),
            
            // MARK: - Home & Lifestyle
            
            // Cooking
            GoalTag(
                title: "Cooking",
                color: themes.first(where: { $0.id == "orange" }) ?? themes[0],
                timeOfDayPreferences: [.afternoon, .evening],
                locationTypes: [.home]
            ),
            
            // Cleaning & Organizing
            GoalTag(
                title: "Cleaning",
                color: themes.first(where: { $0.id == "mint" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .midday],
                locationTypes: [.home]
            ),
            
            // Gardening
            GoalTag(
                title: "Gardening",
                color: themes.first(where: { $0.id == "lime" }) ?? themes[0],
                weatherConditions: [.clear, .partlyCloudy],
                timeOfDayPreferences: [.morning, .afternoon],
                locationTypes: [.outdoor],
                requiresDaylight: true
            ),
            
            // DIY Projects
            GoalTag(
                title: "DIY Projects",
                color: themes.first(where: { $0.id == "burnt_orange" }) ?? themes[0],
                timeOfDayPreferences: [.afternoon],
                locationTypes: [.home],
                requiresDaylight: true
            ),
            
            // MARK: - Social & Family
            
            // Family Time
            GoalTag(
                title: "Family Time",
                color: themes.first(where: { $0.id == "hot_pink" }) ?? themes[0],
                timeOfDayPreferences: [.evening],
                locationTypes: [.home]
            ),
            
            // Social Activities
            GoalTag(
                title: "Social",
                color: themes.first(where: { $0.id == "pink0" }) ?? themes[0],
                timeOfDayPreferences: [.afternoon, .evening],
                locationTypes: [.anywhere]
            ),
            
            // Phone Calls
            GoalTag(
                title: "Calls & Catchup",
                color: themes.first(where: { $0.id == "peach" }) ?? themes[0],
                timeOfDayPreferences: [.afternoon, .evening],
                locationTypes: [.anywhere]
            ),
            
            // MARK: - Time of Day Specific
            
            // Early Morning Routine
            GoalTag(
                title: "Early Morning",
                color: themes.first(where: { $0.id == "sunshine" }) ?? themes[0],
                timeOfDayPreferences: [.morning]
            ),
            
            // Midday Break
            GoalTag(
                title: "Lunch Break",
                color: themes.first(where: { $0.id == "yellow" }) ?? themes[0],
                timeOfDayPreferences: [.midday]
            ),
            
            // Evening Wind Down
            GoalTag(
                title: "Evening Wind Down",
                color: themes.first(where: { $0.id == "mauve" }) ?? themes[0],
                timeOfDayPreferences: [.evening, .night],
                locationTypes: [.home]
            ),
            
            // Weekend Activities
            GoalTag(
                title: "Weekend Special",
                color: themes.first(where: { $0.id == "tangerine" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .midday, .afternoon]
            ),
            
            // MARK: - Weather Specific
            
            // Rainy Day Activities
            GoalTag(
                title: "Cozy Indoor",
                color: themes.first(where: { $0.id == "beige" }) ?? themes[0],
                weatherConditions: [.rainy, .snowy, .cloudy],
                locationTypes: [.home]
            ),
            
            // Sunny Day Activities
            GoalTag(
                title: "Sunny Day",
                color: themes.first(where: { $0.id == "lemon" }) ?? themes[0],
                weatherConditions: [.clear],
                locationTypes: [.outdoor],
                requiresDaylight: true
            ),
            
            // Cold Weather Activities
            GoalTag(
                title: "Winter Activity",
                color: themes.first(where: { $0.id == "cyan" }) ?? themes[0],
                weatherConditions: [.snowy],
                temperatureRange: -10...10
            ),
            
            // Warm Weather Activities
            GoalTag(
                title: "Summer Activity",
                color: themes.first(where: { $0.id == "coral" }) ?? themes[0],
                weatherConditions: [.clear, .partlyCloudy],
                temperatureRange: 20...35
            ),
            
            // MARK: - Energy Level
            
            // High Energy
            GoalTag(
                title: "Energizing",
                color: themes.first(where: { $0.id == "orange" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .midday]
            ),
            
            // Low Energy / Relaxing
            GoalTag(
                title: "Low Key",
                color: themes.first(where: { $0.id == "seafoam" }) ?? themes[0],
                timeOfDayPreferences: [.evening, .night],
                locationTypes: [.home]
            ),
            
            // MARK: - Journaling & Reflection
            
            // Morning Pages
            GoalTag(
                title: "Morning Journal",
                color: themes.first(where: { $0.id == "lemon" }) ?? themes[0],
                timeOfDayPreferences: [.morning],
                locationTypes: [.home]
            ),
            
            // Evening Reflection
            GoalTag(
                title: "Evening Reflection",
                color: themes.first(where: { $0.id == "grape" }) ?? themes[0],
                timeOfDayPreferences: [.evening, .night],
                locationTypes: [.home]
            ),
            
            // Gratitude Practice
            GoalTag(
                title: "Gratitude",
                color: themes.first(where: { $0.id == "pink0" }) ?? themes[0],
                timeOfDayPreferences: [.evening],
                locationTypes: [.home]
            ),
            
            // MARK: - Commute & Travel
            
            // Commute Time
            GoalTag(
                title: "Commute Activity",
                color: themes.first(where: { $0.id == "grey_blue" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .evening],
                locationTypes: [.commute]
            ),
            
            // Podcast Listening
            GoalTag(
                title: "Podcast Time",
                color: themes.first(where: { $0.id == "teal" }) ?? themes[0],
                locationTypes: [.commute, .home]
            ),
            
            // Audiobook
            GoalTag(
                title: "Audiobook",
                color: themes.first(where: { $0.id == "blue" }) ?? themes[0],
                timeOfDayPreferences: [.evening, .night],
                locationTypes: [.home, .commute]
            ),
            
            // MARK: - Self-Care
            
            // Skincare Routine
            GoalTag(
                title: "Skincare",
                color: themes.first(where: { $0.id == "seafoam" }) ?? themes[0],
                timeOfDayPreferences: [.morning, .night],
                locationTypes: [.home]
            ),
            
            // Bath & Relaxation
            GoalTag(
                title: "Self-Care",
                color: themes.first(where: { $0.id == "lilac" }) ?? themes[0],
                timeOfDayPreferences: [.evening, .night],
                locationTypes: [.home]
            ),
            
            // Nap Time
            GoalTag(
                title: "Power Nap",
                color: themes.first(where: { $0.id == "mauve" }) ?? themes[0],
                timeOfDayPreferences: [.midday, .afternoon],
                locationTypes: [.home]
            )
        ]
    }
    
    // MARK: - Context Matching
    
    /// Checks if the tag's weather conditions match the current weather
    /// - Parameter currentWeather: The current weather condition
    /// - Returns: True if there are no weather requirements OR if the current weather matches one of the required conditions
    func matchesWeather(_ currentWeather: WeatherCondition?) -> Bool {
        guard let requiredConditions = weatherConditionsTyped else {
            return true // No weather requirement means it matches any weather
        }
        
        guard let currentWeather = currentWeather else {
            return false // Tag requires specific weather but current weather is unknown
        }
        
        return requiredConditions.contains(currentWeather)
    }
    
    /// Checks if the tag's temperature range matches the current temperature
    /// - Parameter currentTemperature: The current temperature in Celsius
    /// - Returns: True if there are no temperature requirements OR if the current temperature is within range
    func matchesTemperature(_ currentTemperature: Double?) -> Bool {
        guard let min = minTemperature, let max = maxTemperature else {
            return true // No temperature requirement means it matches any temperature
        }
        
        guard let currentTemperature = currentTemperature else {
            return false // Tag requires specific temperature but current temp is unknown
        }
        
        return currentTemperature >= min && currentTemperature <= max
    }
    
    /// Checks if the tag's time of day preferences match the current time
    /// - Parameter currentTimeOfDay: The current time of day
    /// - Returns: True if there are no time preferences OR if the current time matches one of the preferred times
    func matchesTimeOfDay(_ currentTimeOfDay: TimeOfDay?) -> Bool {
        guard let requiredTimes = timeOfDayPreferencesTyped else {
            return true // No time preference means it matches any time
        }
        
        guard let currentTimeOfDay = currentTimeOfDay else {
            return false // Tag requires specific time but current time is unknown
        }
        
        return requiredTimes.contains(currentTimeOfDay)
    }
    
    /// Checks if the tag's location requirements match the current location
    /// - Parameter currentLocation: The current location type
    /// - Returns: True if there are no location requirements OR if the current location matches one of the required locations
    func matchesLocation(_ currentLocation: LocationType?) -> Bool {
        guard let requiredLocations = locationTypesTyped else {
            return true // No location requirement means it matches any location
        }
        
        guard let currentLocation = currentLocation else {
            return false // Tag requires specific location but current location is unknown
        }
        
        return requiredLocations.contains(currentLocation)
    }
    
    /// Comprehensive context matching that checks all trigger conditions
    /// - Parameters:
    ///   - weather: Current weather condition
    ///   - temperature: Current temperature in Celsius
    ///   - timeOfDay: Current time of day
    ///   - location: Current location type
    /// - Returns: True if ALL applicable trigger conditions are met
    func matchesContext(
        weather: WeatherCondition? = nil,
        temperature: Double? = nil,
        timeOfDay: TimeOfDay? = nil,
        location: LocationType? = nil
    ) -> Bool {
        return matchesWeather(weather) &&
               matchesTemperature(temperature) &&
               matchesTimeOfDay(timeOfDay) &&
               matchesLocation(location)
    }
    
    /// Calculates a match score (0.0 to 1.0) representing how well the current context matches this tag's triggers
    /// Higher scores indicate better matches and should result in higher recommendation priority
    /// - Parameters:
    ///   - weather: Current weather condition
    ///   - temperature: Current temperature in Celsius
    ///   - timeOfDay: Current time of day
    ///   - location: Current location type
    /// - Returns: A score from 0.0 (no match) to 1.0 (perfect match)
    func contextMatchScore(
        weather: WeatherCondition? = nil,
        temperature: Double? = nil,
        timeOfDay: TimeOfDay? = nil,
        location: LocationType? = nil
    ) -> Double {
        // If any required condition doesn't match, score is 0
        guard matchesContext(weather: weather, temperature: temperature, timeOfDay: timeOfDay, location: location) else {
            return 0.0
        }
        
        var totalConditions = 0
        var matchedConditions = 0
        
        // Weather matching
        if weatherConditionsTyped != nil {
            totalConditions += 1
            if weather != nil {
                matchedConditions += 1
            }
        }
        
        // Temperature matching
        if minTemperature != nil || maxTemperature != nil {
            totalConditions += 1
            if temperature != nil {
                matchedConditions += 1
            }
        }
        
        // Time of day matching
        if timeOfDayPreferencesTyped != nil {
            totalConditions += 1
            if timeOfDay != nil {
                matchedConditions += 1
            }
        }
        
        // Location matching
        if locationTypesTyped != nil {
            totalConditions += 1
            if location != nil {
                matchedConditions += 1
            }
        }
        
        // If no conditions are defined, return 0.5 (neutral)
        if totalConditions == 0 {
            return 0.5
        }
        
        // Return the proportion of matched conditions
        return Double(matchedConditions) / Double(totalConditions)
    }
}
