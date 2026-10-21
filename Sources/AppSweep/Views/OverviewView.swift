import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Overview", subtitle: "A quick look at what's taking up space on your Mac.") {
                    Button {
                        Task { await model.bootstrap() }
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(GradientButtonStyle())
                }

                if !model.hasFullDiskAccess {
                    FullDiskAccessBanner()
                }

                if let disk = model.disk {
                    DiskCard(disk: disk)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    StatCard(
                        symbol: "square.grid.2x2.fill",
                        title: "Applications",
                        value: model.appsTotalSize.formattedBytes,
                        detail: "\(model.apps.count) apps installed",
                        isLoading: model.isScanningApps,
                        action: "Manage Apps"
                    ) { model.section = .apps }

                    StatCard(
                        symbol: "sparkles",
                        title: "Caches & Logs",
                        value: model.cachesTotalSize.formattedBytes,
                        detail: "\(model.caches.count) items can be cleaned",
                        isLoading: model.isScanningCaches,
                        action: "Clean Up"
                    ) { model.section = .caches }

                    StatCard(
                        symbol: "shippingbox.fill",
                        title: "Leftovers",
                        value: model.leftoversTotalSize.formattedBytes,
                        detail: "\(model.leftovers.count) uninstalled apps left files",
                        isLoading: model.isScanningLeftovers,
                        action: "Review"
                    ) { model.section = .leftovers }
                }

                LargestAppsCard()
            }
            .padding(28)
        }
    }
}

private struct DiskCard: View {
    let disk: DiskInfo

    var body: some View {
        Card(padding: 22) {
            HStack(spacing: 26) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: disk.usedFraction)
                        .stroke(.brand, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(verbatim: "\(Int((disk.usedFraction * 100).rounded()))%")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("used").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Macintosh HD").font(.title3.weight(.semibold))
                    HStack(spacing: 24) {
                        metric("Used", disk.used.formattedBytes, color: .brandStart)
                        metric("Available", disk.available.formattedBytes, color: .green)
                        metric("Total", disk.total.formattedBytes, color: .secondary)
                    }
                }
                Spacer()
            }
        }
    }

    private func metric(_ title: LocalizedStringKey, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(verbatim: value).font(.system(size: 17, weight: .semibold, design: .rounded))
        }
    }
}

private struct StatCard: View {
    let symbol: String
    let title: LocalizedStringKey
    let value: String
    let detail: LocalizedStringKey
    let isLoading: Bool
    let action: LocalizedStringKey
    let onAction: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    IconTile(symbol: symbol)
                    Spacer()
                    if isLoading { ProgressView().controlSize(.small) }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.callout).foregroundStyle(.secondary)
                    Text(verbatim: isLoading && value == Int64(0).formattedBytes ? "—" : value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Text(action)
                        Image(systemName: "chevron.forward")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.brand)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LargestAppsCard: View {
    @Environment(AppModel.self) private var model

    private var largest: [AppItem] {
        Array(model.apps.filter { ($0.size ?? 0) > 0 }.sorted { ($0.size ?? 0) > ($1.size ?? 0) }.prefix(6))
    }

    var body: some View {
        if !largest.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Largest Apps").font(.headline)
                    let maxSize = Double(largest.first?.size ?? 1)
                    ForEach(largest) { app in
                        Button {
                            model.selectedAppID = app.id
                            model.section = .apps
                        } label: {
                            HStack(spacing: 12) {
                                Image(nsImage: app.icon).resizable().frame(width: 28, height: 28)
                                Text(verbatim: app.name).frame(width: 160, alignment: .leading).lineLimit(1)
                                GeometryReader { geo in
                                    Capsule().fill(.brand)
                                        .frame(width: max(6, geo.size.width * Double(app.size ?? 0) / maxSize), height: 8)
                                        .frame(maxHeight: .infinity)
                                }
                                Text(verbatim: (app.size ?? 0).formattedBytes)
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(height: 30)
                    }
                }
            }
        }
    }
}
