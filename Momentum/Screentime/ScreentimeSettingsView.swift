import SwiftUI
import FamilyControls
import ManagedSettings

struct ScreentimeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    let store = ManagedSettingsStore()

    @State var selection = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Restrictions")
                .overlay {
                    VStack {
                        Spacer()
                        HStack {
                            Button {
                                store.application.blockedApplications = []
                                store.shield.applicationCategories = nil
                                dismiss()
                            } label: {
                                Text("Reset")
                            }
                            
                            Button {
                                store.application.blockedApplications = selection.applications
                                store.shield.applicationCategories = .specific(selection.categoryTokens, except: [])
                                dismiss()
                            } label: {
                                Text("Save")
                            }
                        }
                        
                    }
                }
        }
    }
}
