import SwiftUI

struct CacheView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Set<URL> = []
    @State private var permanently = false
    @State private var isWorking = false
    @State private var showConfirm = false

    private var selectedItems: [CleanableItem] { model.caches.filter { selected.contains($0.url) } }
    private var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeader(title: "Cache Cleaner", subtitle: "Free up space by removing data apps can safely rebuild.") {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(verbatim: model.isScanningCaches && model.caches.isEmpty ? "—" : model.cachesTotalSize.formattedBytes)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.brand)
                            Text("reclaimable").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    if model.isScanningCaches && model.caches.isEmpty {
                        ScanningView(message: "Measuring caches…").frame(height: 300)
                    } else if model.caches.isEmpty {
                        EmptyStateView(symbol: "checkmark.seal.fill", title: "All clean",
                                       message: "There are no caches worth cleaning right now.")
                            .frame(height: 300)
                    } else {
                        ForEach(CleanGroup.allCases) { group in
                            let items = model.caches.filter { $0.group == group }
                            if !items.isEmpty { section(group, items: items) }
                        }
                    }
                }
                .padding(24)
            }

            ActionBar {
                Toggle("Delete permanently (skip Trash)", isOn: $permanently)
                    .toggleStyle(.checkbox)
                Button {
                    Task { await model.refreshCaches() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.isScanningCaches)
            } trailing: {
                if isWorking { ProgressView().controlSize(.small) }
                Text("\(selectedItems.count) selected · \(selectedSize.formattedBytes)")
                    .foregroundStyle(.secondary)
                Button {
                    showConfirm = true
                } label: {
                    Label("Clean", systemImage: "sparkles")
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(selectedItems.isEmpty || isWorking)
            }
        }
        .confirmationDialog("Clean \(selectedItems.count) items?", isPresented: $showConfirm) {
            Button(permanently ? "Delete Permanently" : "Move to Trash", role: .destructive) {
                Task {
                    isWorking = true
                    await model.clean(selectedItems, permanently: permanently)
                    selected = selected.filter { url in model.caches.contains { $0.url == url } }
                    isWorking = false
                }
            }
        } message: {
            Text("\(selectedSize.formattedBytes) will be freed. Apps will recreate these caches when needed; quit open apps first for best results.")
        }
    }

    private func section(_ group: CleanGroup, items: [CleanableItem]) -> some View {
        let urls = Set(items.map(\.url))
        let allSelected = urls.isSubset(of: selected)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconTile(symbol: group.symbol, size: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: group.title).font(.headline)
                    Text(verbatim: group.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(verbatim: items.reduce(0) { $0 + $1.size }.formattedBytes)
                    .font(.callout.weight(.semibold).monospacedDigit())
                Button(allSelected ? "Deselect All" : "Select All") {
                    if allSelected { selected.subtract(urls) } else { selected.formUnion(urls) }
                }
                .buttonStyle(.link)
            }
            Card(padding: 6) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        CleanRow(
                            item: item,
                            isOn: Binding(
                                get: { selected.contains(item.url) },
                                set: { if $0 { selected.insert(item.url) } else { selected.remove(item.url) } }
                            )
                        )
                        if item != items.last { Divider().padding(.leading, 48) }
                    }
                }
            }
        }
    }
}

private struct CleanRow: View {
    let item: CleanableItem
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: isOn).toggleStyle(.checkbox).labelsHidden()
            if let icon = IconProvider.icon(forBundleID: item.bundleID) {
                Image(nsImage: icon).resizable().frame(width: 24, height: 24)
            } else {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: item.title).lineLimit(1)
                Text(verbatim: item.url.abbreviatedPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(verbatim: item.size.formattedBytes)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Button { item.url.revealInFinder() } label: { Image(systemName: "arrow.right.circle") }
                .buttonStyle(.borderless)
                .help("Show in Finder")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
    }
}

// MARK: - Leftovers

struct LeftoversView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Set<String> = []
    @State private var expanded: Set<String> = []
    @State private var isWorking = false
    @State private var showConfirm = false

    private var selectedGroups: [LeftoverGroup] { model.leftovers.filter { selected.contains($0.id) } }
    private var selectedSize: Int64 { selectedGroups.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeader(title: "Leftovers", subtitle: "Files left behind by apps that are no longer installed.") {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(verbatim: model.isScanningLeftovers && model.leftovers.isEmpty ? "—" : model.leftoversTotalSize.formattedBytes)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.brand)
                            Text("found").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Label("Review each item before removing — some files may belong to command-line tools or plug-ins.",
                          systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if model.isScanningLeftovers && model.leftovers.isEmpty {
                        ScanningView(message: "Looking for leftovers…").frame(height: 300)
                    } else if model.leftovers.isEmpty {
                        EmptyStateView(symbol: "checkmark.seal.fill", title: "No leftovers",
                                       message: "We didn't find files from uninstalled apps.")
                            .frame(height: 300)
                    } else {
                        Card(padding: 6) {
                            LazyVStack(spacing: 0) {
                                ForEach(model.leftovers) { group in
                                    row(group)
                                    if group != model.leftovers.last { Divider().padding(.leading, 40) }
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }

            ActionBar {
                Button {
                    Task { await model.refreshLeftovers() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.isScanningLeftovers)
            } trailing: {
                if isWorking { ProgressView().controlSize(.small) }
                Text("\(selectedGroups.count) selected · \(selectedSize.formattedBytes)")
                    .foregroundStyle(.secondary)
                Button {
                    showConfirm = true
                } label: {
                    Label("Remove", systemImage: "trash.fill")
                }
                .buttonStyle(GradientButtonStyle(destructive: true))
                .disabled(selectedGroups.isEmpty || isWorking)
            }
        }
        .confirmationDialog("Remove leftovers of \(selectedGroups.count) apps?", isPresented: $showConfirm) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    isWorking = true
                    await model.removeLeftovers(selectedGroups)
                    selected = selected.filter { id in model.leftovers.contains { $0.id == id } }
                    isWorking = false
                }
            }
        } message: {
            Text("\(selectedSize.formattedBytes) will be moved to the Trash.")
        }
    }

    private func row(_ group: LeftoverGroup) -> some View {
        let isExpanded = expanded.contains(group.id)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Toggle("", isOn: Binding(
                    get: { selected.contains(group.id) },
                    set: { if $0 { selected.insert(group.id) } else { selected.remove(group.id) } }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()

                Image(systemName: "shippingbox.fill").foregroundStyle(.brand).frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: group.bundleID).font(.body.monospaced()).lineLimit(1)
                    Text("\(group.files.count) items").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(verbatim: group.size.formattedBytes)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expanded.remove(group.id) } else { expanded.insert(group.id) }
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.files) { file in
                        HStack(spacing: 8) {
                            Image(systemName: file.category.symbol)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            Text(verbatim: file.url.abbreviatedPath)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(verbatim: file.size.formattedBytes)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button { file.url.revealInFinder() } label: { Image(systemName: "arrow.right.circle") }
                                .buttonStyle(.borderless)
                                .font(.caption)
                        }
                    }
                }
                .padding(.leading, 48)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
            }
        }
    }
}
