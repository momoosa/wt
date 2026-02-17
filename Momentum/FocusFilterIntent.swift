import AppIntents
import MomentumKit

/// Allows the user to configure which goal tags are visible during a given Focus mode.
/// Set up in Settings → Focus → [Focus Name] → Add Filter → Momentum.
struct MomentumFocusFilter: SetFocusFilterIntent {

    static var title: LocalizedStringResource = "Filter Goals by Tag"
    static var description = IntentDescription(
        "Only show goals matching the selected tags while this Focus is active."
    )

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Filter Goals by Tag")
    }

    /// The tag titles the user wants to see during this Focus.
    /// Leaving this empty means all goals are shown (no filtering).
    @Parameter(title: "Tags", description: "Goal tags to show during this Focus. Leave empty to show all goals.")
    var tags: [String]?

    func perform() async throws -> some IntentResult {
        let activeTags = tags ?? []
        await MainActor.run {
            FocusFilterStore.shared.activeFocusTagTitles = activeTags
        }
        return .result()
    }
}
