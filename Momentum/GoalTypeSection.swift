import SwiftUI
import MomentumKit

/// Extracted goal type picker section with animated target field
/// Pure presentational component - receives bindings from parent
struct GoalTypeSection: View {
    @Binding var selectedType: Goal.TargetUnit
    @Binding var primaryMetricTarget: Double
    
    let calculatedWeeklyTarget: Int
    let activeThemeColor: Color
    let goalTypeUnit: String
    let targetSuggestions: [Int]
    
    let onTypeChange: (Goal.TargetUnit) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isTargetFocused: Bool
    
    private var displayValue: String {
        if selectedType.isTimeBased {
            return "\(calculatedWeeklyTarget)"
        } else {
            let intVal = Int(primaryMetricTarget)
            return intVal > 0 ? "\(intVal)" : "0"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Big target number + unit picker inline
            targetDisplay
            
            // Label below
            Text(selectedType.isTimeBased ? "Weekly target" : "Daily target")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Quick suggestion chips (non-time types)
            if !selectedType.isTimeBased {
                suggestionChips
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedType)
    }
    
    // MARK: - Target Display
    
    private var targetDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if selectedType.isTimeBased {
                Text(displayValue)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(activeThemeColor)
                    .contentTransition(.numericText())
                    .id("weekly-value")
            } else {
                TextField("0", value: $primaryMetricTarget, format: .number)
                    .keyboardType(.numberPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(activeThemeColor)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .focused($isTargetFocused)
                    .id("daily-value-\(selectedType.rawValue)")
            }
            
            unitMenu
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // MARK: - Unit Menu
    
    private var unitMenu: some View {
        Menu {
            ForEach(Goal.TargetUnit.allCases, id: \.self) { type in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        selectedType = type
                        onTypeChange(type)
                    }
                } label: {
                    Label {
                        Text(type.displayName)
                    } icon: {
                        Image(systemName: type.menuIcon)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(selectedType.isTimeBased ? "min" : goalTypeUnit)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(activeThemeColor.opacity(0.6))
        }
    }
    
    // MARK: - Suggestion Chips
    
    private var suggestionChips: some View {
        HStack(spacing: 8) {
            ForEach(targetSuggestions, id: \.self) { suggestion in
                let isSelected = Int(primaryMetricTarget) == suggestion
                Button {
                    primaryMetricTarget = Double(suggestion)
                } label: {
                    Text("\(suggestion)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? activeThemeColor : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? activeThemeColor.opacity(0.15) : Color(.systemGray6))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
