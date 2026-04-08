import SwiftUI
import EventKit

struct SuggestionsSection: View {
    @Bindable var viewModel: GoalEditorViewModel
    @Binding var scrollProxy: ScrollViewProxy?

    var body: some View {
        Section {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            HStack(spacing: 12) {
                                RemindersTab(isSelected: viewModel.selectedCategoryIndex == -1)
                                    .id(-1)
                                    .onTapGesture {
                                        withAnimation(AnimationPresets.quickSpring) {
                                            viewModel.selectedCategoryIndex = -1
                                        }
                                        HapticFeedbackManager.trigger(.light)
                                    }

                                ForEach(Array(viewModel.suggestionsData.categories.enumerated()), id: \.element.id) { index, category in
                                    CategoryTab(
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
                TabView(selection: $viewModel.selectedCategoryIndex) {
                    RemindersTabView(
                        userInput: $viewModel.userInput,
                        onReminderSelected: { reminder in
                            viewModel.userInput = reminder.title ?? ""
                            viewModel.selectedTemplate = nil
                        }
                    )
                    .tag(-1)

                    ForEach(Array(viewModel.suggestionsData.categories.enumerated()), id: \.element.id) { index, category in
                        CategorySuggestionsView(
                            category: category,
                            selectedTemplate: $viewModel.selectedTemplate,
                            userInput: $viewModel.userInput
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: LayoutConstants.Heights.suggestionPanel)
            }

        } header: {
            Text("Suggestions")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}
