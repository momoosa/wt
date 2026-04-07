import SwiftUI
import MomentumKit

struct WeatherConfigSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    let activeThemeColor: Color
    
    var body: some View {
        Section {
            Toggle(isOn: $viewModel.weatherEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "cloud.sun.fill")
                            .foregroundStyle(activeThemeColor)
                        Text("Weather-Based Visibility")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Text("Show this goal only when weather conditions match")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if viewModel.weatherEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    // Weather conditions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weather Conditions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(WeatherCondition.allCases, id: \.self) { condition in
                                Button(action: {
                                    if viewModel.selectedWeatherConditions.contains(condition) {
                                        viewModel.selectedWeatherConditions.remove(condition)
                                    } else {
                                        viewModel.selectedWeatherConditions.insert(condition)
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: condition.icon)
                                            .font(.title3)
                                        Text(condition.displayName)
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(viewModel.selectedWeatherConditions.contains(condition) ? activeThemeColor.opacity(0.2) : Color(.systemGray6))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(viewModel.selectedWeatherConditions.contains(condition) ? activeThemeColor : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Temperature range
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Temperature Range (°C)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Toggle(isOn: $viewModel.hasMinTemperature) {
                            Text("Minimum Temperature")
                                .font(.subheadline)
                        }
                        
                        if viewModel.hasMinTemperature {
                            HStack {
                                Text("\(Int(viewModel.minTemperature))°C")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50)
                                Slider(value: $viewModel.minTemperature, in: -10...40, step: 1)
                            }
                        }
                        
                        Toggle(isOn: $viewModel.hasMaxTemperature) {
                            Text("Maximum Temperature")
                                .font(.subheadline)
                        }
                        
                        if viewModel.hasMaxTemperature {
                            HStack {
                                Text("\(Int(viewModel.maxTemperature))°C")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50)
                                Slider(value: $viewModel.maxTemperature, in: -10...40, step: 1)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            if viewModel.weatherEnabled {
                HStack {
                    Text("Weather Triggers")
                    Spacer()
                    if viewModel.selectedWeatherConditions.isEmpty && !viewModel.hasMinTemperature && !viewModel.hasMaxTemperature {
                        Text("Select at least one condition")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}
