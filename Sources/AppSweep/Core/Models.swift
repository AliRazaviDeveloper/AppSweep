import AppKit
import Observation

@Observable
final class AppItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    let isAppStore: Bool
    let isProtected: Bool
    let lastUsed: Date?
    let icon: NSImage
    var size: Int64?

    init(url: URL, name: String, bundleID: String?, version: String?,
         isAppStore: Bool, isProtected: Bool, lastUsed: Date?, icon: NSImage) {
        self.id = url.path
        self.url = url
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.isAppStore = isAppStore
        self.isProtected = isProtected
        self.lastUsed = lastUsed
        self.icon = icon
    }

    var isRunning: Bool {
        guard let bundleID else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    static func == (lhs: AppItem, rhs: AppItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum FileCategory: String, CaseIterable, Identifiable, Comparable {
    case application, appSupport, caches, preferences, containers, groupContainers
    case logs, savedState, webData, launchItems, scripts, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .application: String(localized: "Application")
        case .appSupport: String(localized: "Application Support")
        case .caches: String(localized: "Caches")
        case .preferences: String(localized: "Preferences")
        case .containers: String(localized: "Containers")
        case .groupContainers: String(localized: "Group Containers")
        case .logs: String(localized: "Logs")
        case .savedState: String(localized: "Saved State")
        case .webData: String(localized: "Web Data & Cookies")
        case .launchItems: String(localized: "Launch Agents & Helpers")
        case .scripts: String(localized: "Application Scripts")
        case .other: String(localized: "Other")
        }
    }

    var symbol: String {
        switch self {
        case .application: "app.fill"
        case .appSupport: "folder.fill"
        case .caches: "internaldrive.fill"
        case .preferences: "slider.horizontal.3"
        case .containers: "shippingbox.fill"
        case .groupContainers: "square.stack.3d.up.fill"
        case .logs: "doc.text.fill"
        case .savedState: "clock.arrow.circlepath"
        case .webData: "globe"
        case .launchItems: "bolt.fill"
        case .scripts: "applescript.fill"
        case .other: "doc.fill"
        }
    }

    static func < (lhs: FileCategory, rhs: FileCategory) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

struct RelatedFile: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let category: FileCategory
    let size: Int64
}

enum CleanGroup: String, CaseIterable, Identifiable {
    case appCaches, logs, developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appCaches: String(localized: "App Caches")
        case .logs: String(localized: "Logs")
        case .developer: String(localized: "Developer Junk")
        }
    }

    var subtitle: String {
        switch self {
        case .appCaches: String(localized: "Temporary data apps rebuild automatically.")
        case .logs: String(localized: "Diagnostic logs written by apps.")
        case .developer: String(localized: "Xcode build data, simulator caches and package caches.")
        }
    }

    var symbol: String {
        switch self {
        case .appCaches: "internaldrive.fill"
        case .logs: "doc.text.fill"
        case .developer: "hammer.fill"
        }
    }
}

struct CleanableItem: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let title: String
    let bundleID: String?
    let size: Int64
    let group: CleanGroup
}

struct LeftoverGroup: Identifiable, Hashable {
    var id: String { bundleID }
    let bundleID: String
    let files: [RelatedFile]
    var size: Int64 { files.reduce(0) { $0 + $1.size } }
}

struct DiskInfo {
    let total: Int64
    let available: Int64
    var used: Int64 { max(total - available, 0) }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension URL {
    /// Path with the home directory abbreviated to "~".
    var abbreviatedPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
