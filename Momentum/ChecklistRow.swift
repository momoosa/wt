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
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var item: ChecklistItemSession
    @State private var isExpanded = false
    @State private var isTruncated = false
    
    private let collapsedLineLimit = 20
    
    var body: some View {
        let color = item.session?.theme.color(for: colorScheme) ?? ThemeStore.defaultPreset.color(for: colorScheme)
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(item.isCompleted ? color : .secondary)
                    .padding(.top, 2)
                
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
                        .lineLimit(2...20)
                        .scrollDisabled(true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.checklistItem?.title ?? "")
                            .strikethrough(item.isCompleted)
                            .opacity(item.isCompleted ? 0.5 : 1)
                        
                        if let notes = item.checklistItem?.notes, !notes.isEmpty {
                            let bulletedNotes = bulletedText(notes)
                            Text(bulletedNotes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .opacity(item.isCompleted ? 0.4 : 0.7)
                                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                                .background(
                                    // Hidden full-height text to detect truncation
                                    GeometryReader { visibleGeo in
                                        Text(bulletedNotes)
                                            .font(.caption)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .hidden()
                                            .background(
                                                GeometryReader { fullGeo in
                                                    Color.clear.preference(
                                                        key: TruncationPreferenceKey.self,
                                                        value: fullGeo.size.height > visibleGeo.size.height + 1
                                                    )
                                                }
                                            )
                                    }
                                    .hidden()
                                )
                                .onPreferenceChange(TruncationPreferenceKey.self) { value in
                                    isTruncated = value
                                }
                            
                            if isTruncated || isExpanded {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        isExpanded.toggle()
                                    }
                                } label: {
                                    Text(isExpanded ? "Show less" : "Read more")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(color)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func bulletedText(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "•  \($0)" }
            .joined(separator: "\n")
    }
}

private struct TruncationPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

