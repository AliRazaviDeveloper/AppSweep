import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            Group {
                switch model.section ?? .overview {
                case .overview: OverviewView()
                case .apps: AppsView()
                case .caches: CacheView()
                case .leftovers: LeftoversView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 70)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { model.toast = nil }
            }
        }
        .animation(.spring(duration: 0.35), value: model.toast)
        .task { await model.bootstrap() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshSystemInfo()
        }
    }
}

private struct Sidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.section) {
            Section {
                Label("Overview", systemImage: "gauge.with.dots.needle.33percent")
                    .tag(AppModel.Section.overview)
                Label("Applications", systemImage: "square.grid.2x2.fill")
                    .badge(model.apps.count)
                    .tag(AppModel.Section.apps)
                Label("Cache Cleaner", systemImage: "sparkles")
                    .tag(AppModel.Section.caches)
                Label("Leftovers", systemImage: "shippingbox.fill")
                    .badge(model.leftovers.count)
                    .tag(AppModel.Section.leftovers)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 10) {
                IconTile(symbol: "trash.circle.fill", size: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "AppSweep").font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Uninstall & Clean").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .safeAreaInset(edge: .bottom) {
            if let disk = model.disk {
                DiskMiniView(disk: disk).padding(14)
            }
        }
    }
}

private struct DiskMiniView: View {
    let disk: DiskInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "internaldrive")
                Text("Macintosh HD")
                Spacer()
            }
            .font(.caption.weight(.semibold))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(.brand).frame(width: geo.size.width * disk.usedFraction)
                }
            }
            .frame(height: 6)
            Text("\(disk.available.formattedBytes) available")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
    }
}
