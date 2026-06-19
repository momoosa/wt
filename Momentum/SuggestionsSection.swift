import SwiftUI
import EventKit
import MomentumKit

struct SuggestionsSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    @Binding var scrollProxy: ScrollViewProxy?
    @State private var showingPremiumPaywall = false

    var body: some View {
        Section {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            HStack(spacing: 12) {
                                // Featured tab
                                FeaturedTab(isSelected: viewModel.selectedCategoryIndex == -2)
                                    .id(-2)
                                    .onTapGesture {
                                        withAnimation(AnimationPresets.quickSpring) {
                                            viewModel.selectedCategoryIndex = -2
                                        }
                                        HapticFeedbackManager.trigger(.light)
                                    }
                                
                                // Reminders tab
                                RemindersTab(isSelected: viewModel.selectedCategoryIndex == -1)
                                    .id(-1)
                                    .onTapGesture {
                                        withAnimation(AnimationPresets.quickSpring) {
                                            viewModel.selectedCategoryIndex = -1
                                        }
                                        HapticFeedbackManager.trigger(.light)
                                    }

                                ForEach(Array(viewModel.suggestionsData.categories.enumerated()), id: \.element.id) { index, category in
                                    GoalSuggestionCategoryTab(
                                        category: category,
                                        isSelected: viewModel.selectedCategoryIndex == index
                                    )
                                    .id(index)
                                    .onTapGesture {
                                        withAnimation(AnimationPresets.quickSpring) {
                                            viewModel.selectedCategoryIndex = index
                                        }
                                        HapticFeedbackManager.trigger(.light)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical)
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .onChange(of: viewModel.selectedCategoryIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                Group {
                    if viewModel.selectedCategoryIndex == -2 {
                        FeaturedSuggestionsGrid(
                            viewModel: viewModel,
                            showingPremiumPaywall: $showingPremiumPaywall
                        )
                    } else if viewModel.selectedCategoryIndex == -1 {
                        RemindersTabView(
                            userInput: $viewModel.userInput,
                            onReminderSelected: { reminder in
                                viewModel.userInput = reminder.title ?? ""
                                viewModel.selectedTemplate = nil
                            }
                        )
                    } else if let category = viewModel.suggestionsData.categories[safe: viewModel.selectedCategoryIndex] {
                        GoalSuggestionCategoryView(
                            category: category,
                            selectedTemplate: $viewModel.selectedTemplate,
                            userInput: $viewModel.userInput
                        )
                        .id(category.id)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedCategoryIndex)
            }

        } header: {
            Text("Suggestions")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallSheet()
        }
    }
}

// MARK: - Featured Tab Pill

private struct FeaturedTab: View {
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .black : .yellow)
                .padding(8)
                .frame(maxHeight: 30)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            
            Text("Featured")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? .primary : Color(.secondarySystemGroupedBackground))
                .animation(.spring, value: isSelected)
                .transition(.scale)
        )
    }
}

// MARK: - Featured Suggestions Grid

private struct FeaturedSuggestionsGrid: View {
    @Bindable var viewModel: GoalEditorViewModel
    @Binding var showingPremiumPaywall: Bool
    
    var body: some View {
        let items = viewModel.suggestionsData.featuredSuggestions
        
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(items, id: \.suggestion.id) { item in
                SuggestionRow(
                    suggestion: item.suggestion,
                    isSelected: viewModel.selectedTemplate?.id == item.suggestion.id,
                    themePreset: item.category.themePreset
                )
                .onTapGesture {
                    if item.suggestion.isPremium == true {
                        showingPremiumPaywall = true
                    } else {
                        withAnimation(AnimationPresets.quickSpring) {
                            viewModel.selectedTemplate = item.suggestion
                            viewModel.userInput = item.suggestion.title
                        }
                        HapticFeedbackManager.trigger(.light)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}

// MARK: - Premium Paywall Sheet (Stub)

struct PremiumPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.yellow)
                
                Text("Premium Feature")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This goal template requires a premium subscription. Coming soon!")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
