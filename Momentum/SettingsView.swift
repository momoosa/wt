//
//  SettingsView.swift
//  Momentum
//
//  Created by Mo Moosa on 20/01/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("maxPlannedSessions") private var maxPlannedSessions: Int = 5
    @AppStorage("unlimitedPlannedSessions") private var unlimitedPlannedSessions: Bool = false
    @AppStorage("skipPlanningAnimation") private var skipPlanningAnimation: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Unlimited Sessions", isOn: $unlimitedPlannedSessions)
                    
                    if !unlimitedPlannedSessions {
                        Stepper("Max Sessions: \(maxPlannedSessions)", 
                                value: $maxPlannedSessions, 
                                in: 1...20)
                        
                        Text("The AI planner will suggest up to \(maxPlannedSessions) session\(maxPlannedSessions == 1 ? "" : "s") per day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("The AI planner will suggest as many sessions as needed to meet your goals.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("AI Planning", systemImage: "sparkles")
                } footer: {
                    Text("Control how many daily sessions the AI planner can suggest. Fewer sessions create more focused days, while more sessions provide comprehensive coverage of all your goals.")
                }
                
                Section {
                    Toggle("Skip Reveal Animation", isOn: $skipPlanningAnimation)
                    
                    Text(skipPlanningAnimation ? "Sessions will appear instantly." : "Sessions will reveal one by one with animation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Performance", systemImage: "gauge.with.dots.needle.bottom.50percent")
                } footer: {
                    Text("Skipping the animation makes planning feel faster by showing all sessions immediately.")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
