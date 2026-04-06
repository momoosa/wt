import SwiftUI
import MomentumKit

/// Extracted goal type picker section with animated target field
/// Pure presentational component - receives bindings from parent
struct GoalTypeSection: View {
    // Bindings to parent state
    @Binding var selectedType: Goal.GoalType
    @Binding var primaryMetricTarget: Double
    
    // Computed/derived values from parent
    let calculatedWeeklyTarget: Int
    let activeThemeColor: Color
    let goalTypeUnit: String
    let targetSuggestions: [Int]
    
    // Callback for type changes
    let onTypeChange: (Goal.GoalType) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Goal Type", selection: $selectedType) {
                ForEach(Goal.GoalType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedType) { _, newType in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    onTypeChange(newType)
                }
            }

            // Animated target field that morphs between weekly and daily
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(selectedType == .time ? "Weekly Target" : "Daily Target")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .animation(.none, value: selectedType)
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if selectedType == .time {
                            Text("\(calculatedWeeklyTarget)")
                                .foregroundStyle(activeThemeColor)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 100, alignment: .trailing)
                                .id("weekly-value")
                        } else {
                            TextField("Target", value: $primaryMetricTarget, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .id("daily-value-\(selectedType.rawValue)")
                        }
                        
                        Text(selectedType == .time ? "min" : goalTypeUnit)
                            .foregroundStyle(activeThemeColor)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .id("unit-\(selectedType.rawValue)")
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedType)
                
                // Quick suggestion buttons (only for count/calorie)
                if selectedType != .time {
                    HStack(spacing: 8) {
                        Text("Common:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach(targetSuggestions, id: \.self) { suggestion in
                            Button {
                                primaryMetricTarget = Double(suggestion)
                            } label: {
                                Text("\(suggestion)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Int(primaryMetricTarget) == suggestion ? activeThemeColor.opacity(0.2) : Color(.systemGray6))
                                    )
                                    .foregroundStyle(Int(primaryMetricTarget) == suggestion ? activeThemeColor : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedType)
        }
    }
}
