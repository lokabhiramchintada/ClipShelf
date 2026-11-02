import AppKit
import SwiftUI

public struct ClipActions {
    public var paste: (ClipItem) -> Void
    public var copy: (ClipItem) -> Void
    public var togglePin: (ClipItem) -> Void
    public var delete: (ClipItem) -> Void
    public var clearHistory: () -> Void

    public init(paste: @escaping (ClipItem) -> Void, copy: @escaping (ClipItem) -> Void,
                togglePin: @escaping (ClipItem) -> Void, delete: @escaping (ClipItem) -> Void,
                clearHistory: @escaping () -> Void) {
        self.paste = paste
        self.copy = copy
        self.togglePin = togglePin
        self.delete = delete
        self.clearHistory = clearHistory
    }
}

public struct ClipboardView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var model: PanelModel
    let actions: ClipActions
    @FocusState private var searchFocused: Bool

    public init(store: ClipboardStore, model: PanelModel, actions: ClipActions) {
        self.store = store
        self.model = model
        self.actions = actions
    }

    public var body: some View {
        let pinned = model.pinnedResults
        let recent = model.recentResults
        let now = Date()

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search clipboard", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            if pinned.isEmpty && recent.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            if !pinned.isEmpty {
                                sectionHeader("Pinned", systemImage: "pin.fill")
                                ForEach(Array(pinned.enumerated()), id: \.element.id) { i, item in
                                    row(item, index: i, now: now)
                                }
                            }
                            if !recent.isEmpty {
                                sectionHeader("Recent", systemImage: "clock")
                                ForEach(Array(recent.enumerated()), id: \.element.id) { i, item in
                                    row(item, index: pinned.count + i, now: now)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: model.selection) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }

            Divider()

            HStack {
                Text("↩ paste  ⇧↩ copy  ⌘P pin  ⌘⌫ delete")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear history", action: actions.clearHistory)
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .disabled(store.recent.isEmpty)
                    .help("Remove all unpinned items")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 400, minHeight: 480)
        .onChange(of: model.focusToken) { searchFocused = true }
        .onAppear { searchFocused = true }
    }

    private func row(_ item: ClipItem, index: Int, now: Date) -> some View {
        ClipRow(item: item, shortcut: index < 9 ? index + 1 : nil, metadata: item.metadata(relativeTo: now),
                isSelected: model.selection == item.id, actions: actions)
            .id(item.id)
            .onContinuousHover { phase in
                if case .active = phase { model.hover(item.id, mouseLocation: NSEvent.mouseLocation) }
            }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard").font(.system(size: 32)).foregroundStyle(.tertiary)
            Text(model.query.isEmpty ? "Nothing copied yet" : "No matches")
                .foregroundStyle(.secondary)
            if model.query.isEmpty {
                Text("Copy some text and it will show up here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipRow: View {
    let item: ClipItem
    let shortcut: Int?
    let metadata: String
    let isSelected: Bool
    let actions: ClipActions

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(metadata)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .trailing, spacing: 6) {
                if let shortcut {
                    Text("⌘\(shortcut)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 6) {
                    if isSelected || item.pinned {
                        iconButton(item.pinned ? "pin.fill" : "pin", help: item.pinned ? "Unpin" : "Pin") {
                            actions.togglePin(item)
                        }
                        .foregroundStyle(item.pinned ? Color.accentColor : Color.secondary)
                    }
                    if isSelected {
                        iconButton("trash", help: "Delete") { actions.delete(item) }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { actions.paste(item) }
        .contextMenu {
            Button("Paste") { actions.paste(item) }
            Button("Copy") { actions.copy(item) }
            Button(item.pinned ? "Unpin" : "Pin") { actions.togglePin(item) }
            Divider()
            Button("Delete", role: .destructive) { actions.delete(item) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(item.pinned ? "Pinned: \(item.preview)" : item.preview)
    }

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 12))
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(help)
    }
}
