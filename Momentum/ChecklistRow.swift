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
    @State private var showingNotes = false
    
    var body: some View {
        let color = item.session?.theme.dark ?? themePresets[0].dark
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(item.isCompleted ? color : .secondary)
                
                if let editMode, editMode.wrappedValue == .active, let checklistItem = item.checklistItem {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Title", text: Binding(
                            get: { checklistItem.title },
                            set: { checklistItem.title = $0 }
                        ))
                        
                        TextField("Notes (optional)", text: Binding(
                            get: { checklistItem.notes ?? "" },
                            set: { checklistItem.notes = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2...4)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.checklistItem?.title ?? "")
                            .strikethrough(item.isCompleted)
                            .opacity(item.isCompleted ? 0.5 : 1)
                        
                        if let notes = item.checklistItem?.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .opacity(item.isCompleted ? 0.4 : 0.7)
                                .lineLimit(showingNotes ? nil : 2)
                        }
                    }
                }
                
                Spacer()
                
                if let notes = item.checklistItem?.notes, !notes.isEmpty, editMode?.wrappedValue != .active {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showingNotes.toggle()
                        }
                    } label: {
                        Image(systemName: showingNotes ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

