import SwiftUI
import SwiftData
import WeatherKit

public struct GoalTagTriggersEditor: View {
    @Bindable var goalTag: GoalTag
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTimesOfDay: Set<TimeOfDay> = []
    @State private var selectedWeatherConditions: Set<WeatherCondition> = []
    @State private var selectedLocationTypes: Set<LocationType> = []
    @State private var requiresDaylight: Bool = false
    @State private var minTemperatureString: String = ""
    @State private var maxTemperatureString: String = ""

    public var body: some View {
        Form {
            Section(header: Text("Times of Day")) {
                MultipleSelectionPicker(
                    title: "Times of Day",
                    options: TimeOfDay.allCases,
                    selections: $selectedTimesOfDay
                )
            }

            Section(header: Text("Weather Conditions")) {
                MultipleSelectionPicker(
                    title: "Weather Conditions",
                    options: WeatherCondition.allCases,
                    selections: $selectedWeatherConditions
                )
            }

            Section(header: Text("Location Types")) {
                MultipleSelectionPicker(
                    title: "Location Types",
                    options: LocationType.allCases,
                    selections: $selectedLocationTypes
                )
            }

            Section {
                Toggle("Requires Daylight", isOn: $requiresDaylight)
            }

            Section(header: Text("Temperature (°C)")) {
                HStack {
                    Text("Min Temperature")
                    Spacer()
                    TextField("Min", text: $minTemperatureString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Max Temperature")
                    Spacer()
                    TextField("Max", text: $maxTemperatureString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
        }
        .navigationTitle("Edit Triggers")
        .onAppear(perform: loadFromGoalTag)
        .onDisappear(perform: saveToGoalTag)
    }

    public init(goalTag: GoalTag) {
        self.goalTag = goalTag
    }
    
    private func loadFromGoalTag() {
        selectedTimesOfDay = Set(goalTag.requiresTimesOfDay ?? [])
        selectedWeatherConditions = Set(goalTag.requiresWeatherConditions ?? [])
        selectedLocationTypes = Set(goalTag.requiresLocations ?? [])
        requiresDaylight = goalTag.requiresDaylight
        if let minTemp = goalTag.requiresMinTemperature {
            minTemperatureString = String(format: "%.1f", minTemp)
        } else {
            minTemperatureString = ""
        }
        if let maxTemp = goalTag.requiresMaxTemperature {
            maxTemperatureString = String(format: "%.1f", maxTemp)
        } else {
            maxTemperatureString = ""
        }
    }

    private func saveToGoalTag() {
        goalTag.requiresTimesOfDay = Array(selectedTimesOfDay)
        goalTag.requiresWeatherConditions = Array(selectedWeatherConditions)
        goalTag.requiresLocations = Array(selectedLocationTypes)
        goalTag.requiresDaylight = requiresDaylight
        if let minTemp = Double(minTemperatureString) {
            goalTag.requiresMinTemperature = minTemp
        } else {
            goalTag.requiresMinTemperature = nil
        }
        if let maxTemp = Double(maxTemperatureString) {
            goalTag.requiresMaxTemperature = maxTemp
        } else {
            goalTag.requiresMaxTemperature = nil
        }

        // SwiftData automatically saves changes, but we can explicitly save if needed
        do {
            try modelContext.save()
        } catch {
            print("Error saving GoalTag triggers: \(error)")
        }
    }
}

private struct MultipleSelectionPicker<Option: Hashable & CustomStringConvertible>: View {
    let title: String
    let options: [Option]
    @Binding var selections: Set<Option>

    var body: some View {
        List {
            ForEach(options, id: \.self) { option in
                MultipleSelectionRow(title: option.description, isSelected: selections.contains(option)) {
                    if selections.contains(option) {
                        selections.remove(option)
                    } else {
                        selections.insert(option)
                    }
                }
            }
        }
        .frame(height: CGFloat(options.count) * 44)
    }
}

private struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Provide CustomStringConvertible conformance for enums to display nicely
extension TimeOfDay: CustomStringConvertible {
    public var description: String {
        displayName
    }
}

extension WeatherCondition: CustomStringConvertible {
    public var description: String {
        displayName
    }
}

extension LocationType: CustomStringConvertible {
    public var description: String {
        displayName
    }
}


//
//extension GoalTag {
//    var requiresTimesOfDay: [TimeOfDay]? {
//        get { (self.primitiveValue(forKey: "requiresTimesOfDay") as? [TimeOfDay]) }
//        set { self.setPrimitiveValue(newValue, forKey: "requiresTimesOfDay") }
//    }
//    var requiresWeatherConditions: [WeatherCondition]? {
//        get { (self.primitiveValue(forKey: "requiresWeatherConditions") as? [WeatherCondition]) }
//        set { self.setPrimitiveValue(newValue, forKey: "requiresWeatherConditions") }
//    }
//    var requiresLocations: [LocationType]? {
//        get { (self.primitiveValue(forKey: "requiresLocations") as? [LocationType]) }
//        set { self.setPrimitiveValue(newValue, forKey: "requiresLocations") }
//    }
//    var requiresDaylight: Bool {
//        get { self.primitiveValue(forKey: "requiresDaylight") as? Bool ?? false }
//        set { self.setPrimitiveValue(newValue, forKey: "requiresDaylight") }
//    }
//    var requiresMinTemperature: Double? {
//        get { self.primitiveValue(forKey: "requiresMinTemperature") as? Double }
//        set { self.setPrimitiveValue(newValue, forKey: "requiresMinTemperature") }
//    }
//    var requiresMaxTemperature: Double? {
//        get { self.primitiveValue(forKey: "requiresMaxTemperature") as? Double }
//        set { self.setPrimitiveValue(newValue, forKey: "requiresMaxTemperature") }
//    }
//}
