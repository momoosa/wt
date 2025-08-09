//
//  ChecklistRow.swift
//  Weektime
//
//  Created by Mo Moosa on 09/08/2025.
//
import SwiftUI
import SwiftData
import WeektimeKit

struct ChecklistRow: View {
    @Environment(\.editMode) var editMode
    @Bindable var item: ChecklistItemSession
    var body: some View {
        HStack {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(item.isCompleted ? .green : .secondary)
            if let editMode, editMode.wrappedValue == .active {
                TextField("Type here", text: $item.checklistItem.title)
                    
            } else {
                
                Text(item.checklistItem.title)
                    .strikethrough(item.isCompleted)
                    .opacity(item.isCompleted ? 0.5 : 1)
            }
            Spacer()
        }
        
    }
}

