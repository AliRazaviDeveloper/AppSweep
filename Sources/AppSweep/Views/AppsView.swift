import SwiftUI

struct AppsView: View {
    @Environment(AppModel.self) private var model
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            AppListView()
                .frame(width: 330)
            Divider()
            Group {
                if let app = model.selectedApp {
                    AppDetailView(app: app).id(app.id)
                } else {
                    EmptyStateView(
                        symbol: "hand.point.up.left.fill",
                        title: "Select an app",
                        message: "Pick an app from the list — or drag any app onto this window — to see everything it stores on your Mac."
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.brand, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension == "app" }) else { return false }
            model.reveal(appAt: url)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }
}

// MARK: - List

private enum AppSort: String, CaseIterable, Identifiable {
    case name, size, lastUsed
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .name: "Name"
        case .size: "Size"
        case .lastUsed: "Last Used"
        }
    }
}

private struct AppListView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var sort: AppSort = .name

    private var filtered: [AppItem] {
        let base = query.isEmpty ? model.apps : model.apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.bundleID?.localizedCaseInsensitiveContains(query) ?? false)
        }
        switch sort {
        case .name: return base
        case .size: return base.sorted { ($0.size ?? 0) > ($1.size ?? 0) }
        case .lastUsed: return base.sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search apps", text: $query).textFieldStyle(.plain)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.06)))

                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(AppSort.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    Task { await model.refreshApps() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Rescan")
            }
            .padding(12)

            if model.isScanningApps && model.apps.isEmpty {
                ScanningView(message: "Finding your apps…")
            } else {
                List(filtered, selection: $model.selectedAppID) { app in
                    AppRow(app: app).tag(app.id)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }

            HStack {
                Text("\(filtered.count) apps")
                Spacer()
                Text(verbatim: model.appsTotalSize.formattedBytes)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .overlay(alignment: .top) { Divider() }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

private struct AppRow: View {
    let app: AppItem

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(verbatim: app.name).fontWeight(.medium).lineLimit(1)
                    if app.isProtected {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text(verbatim: app.version.map { "v\($0)" } ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let size = app.size {
                Text(verbatim: size.formattedBytes)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Detail

struct AppDetailView: View {
    @Environment(AppModel.self) private var model
    let app: AppItem

    @State private var files: [RelatedFile] = []
    @State private var selected: Set<URL> = []
    @State private var includeApp = true
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var showConfirm = false

    private var grouped: [(FileCategory, [RelatedFile])] {
        Dictionary(grouping: files, by: \.category)
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    private var selectedFiles: [RelatedFile] { files.filter { selected.contains($0.url) } }
    private var removesApp: Bool { includeApp && !app.isProtected }

    private var selectedSize: Int64 {
        selectedFiles.reduce(0) { $0 + $1.size } + (removesApp ? app.size ?? 0 : 0)
    }

    private var selectedCount: Int { selectedFiles.count + (removesApp ? 1 : 0) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if app.isProtected {
                        Label("This app is part of macOS and can't be removed. You can still clean its data.",
                              systemImage: "lock.shield")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    filesSection
                }
                .padding(24)
            }

            ActionBar {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(selectedCount) items selected").font(.callout.weight(.medium))
                    Text(verbatim: selectedSize.formattedBytes).font(.caption).foregroundStyle(.secondary)
                }
            } trailing: {
                if isWorking { ProgressView().controlSize(.small) }
                Button {
                    showConfirm = true
                } label: {
                    Label(removesApp ? "Uninstall" : "Remove Selected Files",
                          systemImage: removesApp ? "trash.fill" : "eraser.fill")
                }
                .buttonStyle(GradientButtonStyle(destructive: true))
                .disabled(selectedCount == 0 || isWorking || isLoading)
            }
        }
        .confirmationDialog(removesApp ? "Uninstall \(app.name)?" : "Remove the selected files?",
                            isPresented: $showConfirm) {
            Button(removesApp ? "Move to Trash" : "Remove Files", role: .destructive) {
                Task {
                    isWorking = true
                    await model.uninstall(app, includeApp: removesApp, files: selectedFiles)
                    isWorking = false
                    if model.selectedAppID == app.id { await loadFiles() }
                }
            }
        } message: {
            Text("\(selectedCount) items (\(selectedSize.formattedBytes)) will be moved to the Trash. You can restore them from the Trash if needed.")
        }
        .task { await loadFiles() }
    }

    private func loadFiles() async {
        isLoading = true
        let bundleID = app.bundleID
        let names = [app.name, app.url.deletingPathExtension().lastPathComponent]
        let url = app.url
        let found = await Task.detached(priority: .userInitiated) {
            RelatedFinder.find(bundleID: bundleID, names: names, appURL: url)
        }.value
        files = found
        selected = Set(found.map(\.url))
        includeApp = !app.isProtected
        isLoading = false
    }

    private var header: some View {
        Card(padding: 22) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 76, height: 76)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: app.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        if let bundleID = app.bundleID {
                            Text(verbatim: bundleID)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        if let lastUsed = app.lastUsed {
                            Text("Last opened \(lastUsed, format: .relative(presentation: .named))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        if let size = app.size {
                            Text(verbatim: size.formattedBytes)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.brand)
                        } else {
                            ProgressView().controlSize(.small)
                        }
                        Text("App size").font(.caption).foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }

                HStack(spacing: 6) {
                    if let version = app.version { Chip(text: "v\(version)", symbol: "tag.fill") }
                    if app.isAppStore { Chip(text: String(localized: "App Store"), symbol: "bag.fill", tint: .blue) }
                    if app.isRunning { Chip(text: String(localized: "Running"), symbol: "circle.fill", tint: .green) }
                    if app.isProtected { Chip(text: String(localized: "System"), symbol: "lock.fill", tint: .orange) }
                    Spacer()
                    Button { NSWorkspace.shared.open(app.url) } label: {
                        Label("Open", systemImage: "play.fill")
                    }
                    Button { app.url.revealInFinder() } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var filesSection: some View {
        HStack {
            Text("What will be removed").font(.headline)
            Spacer()
            if !files.isEmpty {
                Button(selected.count == files.count ? "Deselect All" : "Select All") {
                    selected = selected.count == files.count ? [] : Set(files.map(\.url))
                }
                .buttonStyle(.link)
            }
        }

        Card(padding: 6) {
            VStack(spacing: 0) {
                FileRow(
                    symbol: FileCategory.application.symbol,
                    title: app.url.lastPathComponent,
                    path: app.url.abbreviatedPath,
                    size: app.size,
                    isOn: Binding(get: { removesApp }, set: { includeApp = $0 }),
                    disabled: app.isProtected,
                    url: app.url
                )
                if isLoading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Searching for related files…").foregroundStyle(.secondary)
                    }
                    .padding(14)
                } else if files.isEmpty {
                    Text("No related files found.")
                        .foregroundStyle(.secondary)
                        .padding(14)
                }
            }
        }

        ForEach(grouped, id: \.0) { category, items in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: category.symbol).foregroundStyle(.brand)
                    Text(verbatim: category.title).font(.subheadline.weight(.semibold))
                    Text(verbatim: "· \(items.reduce(0) { $0 + $1.size }.formattedBytes)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Card(padding: 6) {
                    VStack(spacing: 0) {
                        ForEach(items) { file in
                            FileRow(
                                symbol: nil,
                                title: file.url.lastPathComponent,
                                path: file.url.deletingLastPathComponent().abbreviatedPath,
                                size: file.size,
                                isOn: Binding(
                                    get: { selected.contains(file.url) },
                                    set: { if $0 { selected.insert(file.url) } else { selected.remove(file.url) } }
                                ),
                                disabled: false,
                                url: file.url
                            )
                            if file != items.last { Divider().padding(.leading, 40) }
                        }
                    }
                }
            }
        }
    }
}

struct FileRow: View {
    let symbol: String?
    let title: String
    let path: String
    let size: Int64?
    let isOn: Binding<Bool>
    let disabled: Bool
    let url: URL

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(disabled)
            if let symbol {
                Image(systemName: symbol).foregroundStyle(.brand).frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: title).lineLimit(1).truncationMode(.middle)
                Text(verbatim: path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let size {
                Text(verbatim: size.formattedBytes)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button { url.revealInFinder() } label: {
                Image(systemName: "arrow.right.circle")
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .opacity(disabled ? 0.5 : 1)
    }
}
