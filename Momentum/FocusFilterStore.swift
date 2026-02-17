import Foundation
import Observation

private let appGroupID = "group.com.moosa.ios.momentum"
private let focusTagsKey = "focusFilterActiveTags"

/// Persists and vends the tag titles that the active Focus filter has requested.
/// Written by `MomentumFocusFilter.perform()` and read by `ContentView`.
@Observable
final class FocusFilterStore {

    static let shared = FocusFilterStore()

    /// Tag titles selected by the user for the currently-active Focus.
    /// An empty array means no Focus filter is active — show all goals.
    var activeFocusTagTitles: [String] {
        get {
            defaults?.stringArray(forKey: focusTagsKey) ?? []
        }
        set {
            defaults?.set(newValue, forKey: focusTagsKey)
        }
    }

    var isFocusFilterActive: Bool {
        !activeFocusTagTitles.isEmpty
    }

    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: appGroupID)
    }
}
