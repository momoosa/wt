import Foundation
import FoundationModels

// MARK: - AI Suggestion Model
@Generable
struct GoalThemeSuggestionsResponse: Codable {
    var suggestedThemes: [String] // Array of theme names (e.g., ["Wellness", "Fitness", "Productivity"])
    var reasoning: String? // optional explanation
}

// MARK: - Checklist Item Data
struct ChecklistItemData: Identifiable, Equatable {
    let id: UUID
    var title: String
    var notes: String

    init(id: UUID = UUID(), title: String = "", notes: String = "") {
        self.id = id
        self.title = title
        self.notes = notes
    }
}
