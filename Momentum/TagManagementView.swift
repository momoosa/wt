//
//  TagManagementView.swift
//  Momentum
//
//  Manage, rename, and delete goal tags.
//

import SwiftUI
import SwiftData
import MomentumKit

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \GoalTag.title) private var allTags: [GoalTag]
    
    @State private var tagToDelete: GoalTag?
    @State private var tagToRename: GoalTag?
    @State private var renameText: String = ""
    @State private var showingDeleteConfirmation = false
    @State private var sortOrder: TagSortOrder = .name
    @State private var isSelecting = false
    @State private var selectedTagIDs: Set<PersistentIdentifier> = []
    @State private var showingBulkDeleteConfirmation = false
    @State private var showingNewTag = false
    @State private var newTagName: String = ""
    
    enum TagSortOrder: String, CaseIterable {
        case name = "Name"
        case goalCount = "Goals"
        case unusedFirst = "Unused First"
    }
    
    private var sortedTags: [GoalTag] {
        switch sortOrder {
        case .name:
            return allTags.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .goalCount:
            return allTags.sorted { ($0.goalsAsPrimary?.count ?? 0) > ($1.goalsAsPrimary?.count ?? 0) }
        case .unusedFirst:
            return allTags.sorted {
                let c0 = $0.goalsAsPrimary?.count ?? 0
                let c1 = $1.goalsAsPrimary?.count ?? 0
                if c0 == 0 && c1 != 0 { return true }
                if c0 != 0 && c1 == 0 { return false }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }
    
    private var selectedTags: [GoalTag] {
        allTags.filter { selectedTagIDs.contains($0.persistentModelID) }
    }
    
    private var totalAffectedGoals: Int {
        selectedTags.reduce(0) { $0 + ($1.goalsAsPrimary?.count ?? 0) }
    }
    
    var body: some View {
        List {
            if allTags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag.slash",
                    description: Text("Tags will appear here once you add goals.")
                )
            } else {
                ForEach(sortedTags, id: \.persistentModelID) { tag in
                    if isSelecting {
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                toggleSelection(tag)
                            }
                        } label: {
                            tagRow(tag, selectable: true)
                        }
                        .listRowBackground(
                            selectedTagIDs.contains(tag.persistentModelID)
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                        )
                    } else {
                        tagRow(tag)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    tagToDelete = tag
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    tagToRename = tag
                                    renameText = tag.title
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
        }
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Menu {
                        Button {
                            newTagName = ""
                            showingNewTag = true
                        } label: {
                            Label("New Tag", systemImage: "plus")
                        }
                        
                        Divider()
                        
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(TagSortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.subheadline)
                    }
                    
                    Button {
                        withAnimation {
                            isSelecting.toggle()
                            if !isSelecting {
                                selectedTagIDs.removeAll()
                            }
                        }
                    } label: {
                        Text(isSelecting ? "Done" : "Select")
                            .font(.subheadline)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting && !selectedTagIDs.isEmpty {
                Button(role: .destructive) {
                    showingBulkDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete \(selectedTagIDs.count) Tag\(selectedTagIDs.count == 1 ? "" : "s")")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Delete Tag", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                tagToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    deleteTag(tag)
                }
                tagToDelete = nil
            }
        } message: {
            if let tag = tagToDelete {
                let count = tag.goalsAsPrimary?.count ?? 0
                if count > 0 {
                    Text("This will remove \"\(tag.title)\" from \(count) goal\(count == 1 ? "" : "s"). The goals themselves won't be deleted.")
                } else {
                    Text("Delete the tag \"\(tag.title)\"? It's not used by any goals.")
                }
            }
        }
        .alert("Delete \(selectedTagIDs.count) Tag\(selectedTagIDs.count == 1 ? "" : "s")", isPresented: $showingBulkDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteBulkTags()
            }
        } message: {
            if totalAffectedGoals > 0 {
                Text("This will remove tags from \(totalAffectedGoals) goal\(totalAffectedGoals == 1 ? "" : "s"). The goals themselves won't be deleted.")
            } else {
                Text("Delete \(selectedTagIDs.count) unused tag\(selectedTagIDs.count == 1 ? "" : "s")?")
            }
        }
        .alert("New Tag", isPresented: $showingNewTag) {
            TextField("Tag name", text: $newTagName)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                createTag()
            }
        } message: {
            Text("Enter a name for the new tag.")
        }
        .alert("Rename Tag", isPresented: Binding(
            get: { tagToRename != nil },
            set: { if !$0 { tagToRename = nil } }
        )) {
            TextField("Tag name", text: $renameText)
            Button("Cancel", role: .cancel) {
                tagToRename = nil
            }
            Button("Rename") {
                if let tag = tagToRename, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    tag.title = renameText.trimmingCharacters(in: .whitespaces)
                    modelContext.safeSave()
                }
                tagToRename = nil
            }
        } message: {
            Text("Enter a new name for this tag.")
        }
    }
    
    // MARK: - Tag Row
    
    private func tagRow(_ tag: GoalTag, selectable: Bool = false) -> some View {
        HStack(spacing: 12) {
            if selectable {
                let isSelected = selectedTagIDs.contains(tag.persistentModelID)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            
            RoundedRectangle(cornerRadius: 6)
                .fill(tag.theme.gradient(for: colorScheme))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                let goalCount = tag.goalsAsPrimary?.count ?? 0
                Text(goalCount == 0 ? "Unused" : "\(goalCount) goal\(goalCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(goalCount == 0 ? .orange : .secondary)
            }
            
            Spacer()
            
            if tag.isSmart {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Actions
    
    private func toggleSelection(_ tag: GoalTag) {
        let id = tag.persistentModelID
        if selectedTagIDs.contains(id) {
            selectedTagIDs.remove(id)
        } else {
            selectedTagIDs.insert(id)
        }
    }
    
    private func deleteTag(_ tag: GoalTag) {
        withAnimation {
            modelContext.delete(tag)
            modelContext.safeSave()
        }
    }
    
    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        // Pick a theme that isn't already used by existing tags
        let usedThemeIDs = Set(allTags.map { $0.themeID })
        let availablePreset = ThemeStore.presets.first { !usedThemeIDs.contains($0.id) }
            ?? ThemeStore.presets.randomElement()
            ?? ThemeStore.defaultPreset
        
        withAnimation {
            let tag = GoalTag(title: name, themeID: availablePreset.id)
            modelContext.insert(tag)
            modelContext.safeSave()
        }
    }
    
    private func deleteBulkTags() {
        withAnimation {
            for tag in selectedTags {
                modelContext.delete(tag)
            }
            modelContext.safeSave()
            selectedTagIDs.removeAll()
            isSelecting = false
        }
    }
}
