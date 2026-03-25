//
//  ChecklistRow.swift
//  Momentum
//
//  Created by Mo Moosa on 09/08/2025.
//
import SwiftUI
import SwiftData
import MomentumKit

struct ChecklistRow: View {
    @Environment(\.editMode) var editMode
    @Bindable var item: ChecklistItemSession
    var body: some View {
        let color = item.session?.theme.dark ?? Theme.default.dark
        
        return HStack {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(item.isCompleted ? color : .secondary)
            if let editMode, editMode.wrappedValue == .active, let checklistItem = item.checklistItem {
                TextField("Type here", text: Binding(
                    get: { checklistItem.title },
                    set: { checklistItem.title = $0 }
                ))
                    
            } else {
                
                Text(item.checklistItem?.title ?? "")
                    .strikethrough(item.isCompleted)
                    .opacity(item.isCompleted ? 0.5 : 1)
            }
            Spacer()
        }
        
    }
}

