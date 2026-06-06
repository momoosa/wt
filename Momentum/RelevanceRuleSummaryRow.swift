import SwiftUI
import MomentumKit

struct RelevanceRuleSummaryRow: View {
    @Bindable var viewModel: GoalEditorViewModel
    let activeThemeColor: Color
    
    var body: some View {
        Section {
            Button {
                viewModel.showingRelevanceRuleSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                        .foregroundStyle(activeThemeColor)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Relevance Rule")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Text(viewModel.compactRelevanceSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("When to Suggest")
        } footer: {
            Text("Configure when Momentum should surface this goal based on day, time, weather, and other signals.")
        }
    }
}
