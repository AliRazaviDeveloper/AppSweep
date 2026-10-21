import AppKit
import Observation

@Observable
@MainActor
final class AppModel {
    enum Section: Hashable {
        case overview, apps, caches, leftovers
    }

    var section: Section? = .overview

    var apps: [AppItem] = []
    var selectedAppID: AppItem.ID?
    var isScanningApps = false

    var caches: [CleanableItem] = []
    var isScanningCaches = false

    var leftovers: [LeftoverGroup] = []
    var isScanningLeftovers = false

    var disk: DiskInfo?
    var hasFullDiskAccess = true
    var toast: Toast?

    var selectedApp: AppItem? {
        apps.first { $0.id == selectedAppID }
    }

    var appsTotalSize: Int64 { apps.reduce(0) { $0 + ($1.size ?? 0) } }
    var cachesTotalSize: Int64 { caches.reduce(0) { $0 + $1.size } }
    var leftoversTotalSize: Int64 { leftovers.reduce(0) { $0 + $1.size } }

    func bootstrap() async {
        refreshSystemInfo()
        async let caches: Void = refreshCaches()
        await refreshApps()
        await refreshLeftovers()
        await caches
    }

    func refreshSystemInfo() {
        disk = SystemInfo.disk()
        hasFullDiskAccess = SystemInfo.hasFullDiskAccess
    }

    // MARK: Apps

    func refreshApps() async {
        isScanningApps = true
        let items = await Task.detached(priority: .userInitiated) { AppScanner.scan() }.value
        apps = items
        isScanningApps = false
        Task { await computeSizes(for: items) }
    }

    private func computeSizes(for items: [AppItem]) async {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let jobs = items.map { ($0.id, $0.url) }
        await withTaskGroup(of: (String, Int64).self) { group in
            var next = 0
            func enqueue() {
                guard next < jobs.count else { return }
                let (id, url) = jobs[next]
                next += 1
                group.addTask { (id, FileSizer.size(of: url)) }
            }
            for _ in 0..<6 { enqueue() }
            for await (id, size) in group {
                byID[id]?.size = size
                enqueue()
            }
        }
    }

    /// Adds an app that was dropped onto the window (it may live outside the scanned folders).
    func reveal(appAt url: URL) {
        if let existing = apps.first(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            selectedAppID = existing.id
        } else if let item = AppScanner.makeItem(url) {
            apps.append(item)
            apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            selectedAppID = item.id
            Task { await computeSizes(for: [item]) }
        }
        section = .apps
    }

    func uninstall(_ app: AppItem, includeApp: Bool, files: [RelatedFile]) async {
        if includeApp, app.isRunning, let bundleID = app.bundleID {
            for running in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                running.terminate()
            }
            for _ in 0..<30 where app.isRunning {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        var urls = files.map(\.url)
        if includeApp { urls.insert(app.url, at: 0) }
        let outcome = await Remover.remove(urls, permanently: false)

        let freed = (includeApp && outcome.removed.contains(app.url) ? app.size ?? 0 : 0)
            + files.filter { outcome.removed.contains($0.url) }.reduce(0) { $0 + $1.size }

        if includeApp && outcome.removed.contains(app.url) {
            apps.removeAll { $0.id == app.id }
            selectedAppID = nil
            show(String(localized: "\(app.name) was moved to the Trash · \(freed.formattedBytes) freed"))
        } else if outcome.failed.isEmpty {
            show(String(localized: "Removed \(outcome.removed.count) items · \(freed.formattedBytes) freed"))
        }
        if !outcome.failed.isEmpty {
            show(String(localized: "\(outcome.failed.count) items couldn't be removed"), isError: true)
        }
        refreshSystemInfo()
    }

    // MARK: Caches

    func refreshCaches() async {
        isScanningCaches = true
        caches = await Task.detached(priority: .userInitiated) { CacheScanner.scan() }.value
        isScanningCaches = false
    }

    func clean(_ items: [CleanableItem], permanently: Bool) async {
        let outcome = await Remover.remove(items.map(\.url), permanently: permanently)
        let freed = items.filter { outcome.removed.contains($0.url) }.reduce(0) { $0 + $1.size }
        caches.removeAll { outcome.removed.contains($0.url) }
        report(outcome, freed: freed)
    }

    // MARK: Leftovers

    func refreshLeftovers() async {
        isScanningLeftovers = true
        let installed = apps.map(\.url)
        leftovers = await Task.detached(priority: .utility) {
            LeftoverScanner.scan(installedApps: installed)
        }.value
        isScanningLeftovers = false
    }

    func removeLeftovers(_ groups: [LeftoverGroup]) async {
        let files = groups.flatMap(\.files)
        let outcome = await Remover.remove(files.map(\.url), permanently: false)
        let freed = files.filter { outcome.removed.contains($0.url) }.reduce(0) { $0 + $1.size }
        leftovers = leftovers.compactMap { group in
            let remaining = group.files.filter { !outcome.removed.contains($0.url) }
            return remaining.isEmpty ? nil : LeftoverGroup(bundleID: group.bundleID, files: remaining)
        }
        report(outcome, freed: freed)
    }

    // MARK: Feedback

    private func report(_ outcome: Remover.Outcome, freed: Int64) {
        if outcome.failed.isEmpty {
            show(String(localized: "Removed \(outcome.removed.count) items · \(freed.formattedBytes) freed"))
        } else {
            show(String(localized: "\(outcome.failed.count) items couldn't be removed"), isError: true)
        }
        refreshSystemInfo()
    }

    func show(_ message: String, isError: Bool = false) {
        let toast = Toast(message: message, isError: isError)
        self.toast = toast
        Task {
            try? await Task.sleep(for: .seconds(4))
            if self.toast == toast { self.toast = nil }
        }
    }
}
