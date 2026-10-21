import AppKit
import CoreServices

enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let library = home.appendingPathComponent("Library")

    static func lib(_ path: String) -> URL { library.appendingPathComponent(path) }
    static func home(_ path: String) -> URL { home.appendingPathComponent(path) }
}

// MARK: - Sizes

enum FileSizer {
    private static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// Allocated size on disk of a file or an entire directory tree.
    static func size(of url: URL) -> Int64 {
        let keySet = Set(keys)
        guard let values = try? url.resourceValues(forKeys: keySet) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys, options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let v = try? file.resourceValues(forKeys: keySet), v.isDirectory != true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return total
    }
}

// MARK: - Installed applications

enum AppScanner {
    static var roots: [URL] {
        [URL(fileURLWithPath: "/Applications"), Paths.home("Applications")]
    }

    static func scan() -> [AppItem] {
        let fm = FileManager.default
        var candidates: [URL] = []
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            ) else { continue }
            for entry in entries {
                if entry.pathExtension == "app" {
                    candidates.append(entry)
                } else if (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                          let nested = try? fm.contentsOfDirectory(
                            at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    candidates += nested.filter { $0.pathExtension == "app" }
                }
            }
        }

        var seen = Set<String>()
        return candidates
            .filter { seen.insert($0.resolvingSymlinksInPath().path).inserted }
            .compactMap(makeItem)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func makeItem(_ url: URL) -> AppItem? {
        guard url.pathExtension == "app" else { return nil }
        let info = Bundle(url: url)?.infoDictionary ?? [:]
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        let bundleID = info["CFBundleIdentifier"] as? String
        let version = (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String)
        let receipt = url.appendingPathComponent("Contents/_MASReceipt/receipt")

        return AppItem(
            url: url,
            name: name,
            bundleID: bundleID,
            version: version,
            isAppStore: FileManager.default.fileExists(atPath: receipt.path),
            isProtected: isSystemProtected(url) || bundleID == "com.apple.Safari",
            lastUsed: lastUsedDate(url),
            icon: NSWorkspace.shared.icon(forFile: url.path)
        )
    }

    /// Apps protected by System Integrity Protection can't be removed.
    private static func isSystemProtected(_ url: URL) -> Bool {
        if url.path.hasPrefix("/System/") { return true }
        var st = stat()
        guard lstat(url.path, &st) == 0 else { return false }
        let restricted: UInt32 = 0x0008_0000 // SF_RESTRICTED
        return st.st_flags & restricted != 0
    }

    private static func lastUsedDate(_ url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }
}

// MARK: - Files related to an app

enum RelatedFinder {
    enum Match { case exact, contains }

    struct Location {
        let url: URL
        let category: FileCategory
        let match: Match
    }

    static var locations: [Location] {
        let system = URL(fileURLWithPath: "/Library")
        return [
            Location(url: Paths.lib("Application Support"), category: .appSupport, match: .exact),
            Location(url: Paths.lib("Caches"), category: .caches, match: .exact),
            Location(url: Paths.lib("Preferences"), category: .preferences, match: .exact),
            Location(url: Paths.lib("Preferences/ByHost"), category: .preferences, match: .exact),
            Location(url: Paths.lib("Containers"), category: .containers, match: .exact),
            Location(url: Paths.lib("Group Containers"), category: .groupContainers, match: .contains),
            Location(url: Paths.lib("Logs"), category: .logs, match: .exact),
            Location(url: Paths.lib("Saved Application State"), category: .savedState, match: .exact),
            Location(url: Paths.lib("HTTPStorages"), category: .webData, match: .exact),
            Location(url: Paths.lib("WebKit"), category: .webData, match: .exact),
            Location(url: Paths.lib("Cookies"), category: .webData, match: .exact),
            Location(url: Paths.lib("LaunchAgents"), category: .launchItems, match: .contains),
            Location(url: Paths.lib("Application Scripts"), category: .scripts, match: .exact),
            Location(url: system.appendingPathComponent("Application Support"), category: .appSupport, match: .exact),
            Location(url: system.appendingPathComponent("Caches"), category: .caches, match: .exact),
            Location(url: system.appendingPathComponent("Preferences"), category: .preferences, match: .exact),
            Location(url: system.appendingPathComponent("Logs"), category: .logs, match: .exact),
            Location(url: system.appendingPathComponent("LaunchAgents"), category: .launchItems, match: .contains),
            Location(url: system.appendingPathComponent("LaunchDaemons"), category: .launchItems, match: .contains),
            Location(url: system.appendingPathComponent("PrivilegedHelperTools"), category: .launchItems, match: .contains),
        ]
    }

    private static let strippedExtensions: Set<String> = ["plist", "savedstate", "binarycookies", "log"]

    /// File name without well-known suffixes such as ".plist" (bundle IDs contain dots, so
    /// only these extensions are removed).
    static func stem(of name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        return strippedExtensions.contains(ext) ? (name as NSString).deletingPathExtension : name
    }

    static func find(bundleID: String?, names: [String], appURL: URL) -> [RelatedFile] {
        let fm = FileManager.default
        let id = bundleID?.lowercased()
        let names = Set(names.map { $0.lowercased() }.filter { $0.count >= 3 })
        var found: [(URL, FileCategory)] = []

        for location in locations {
            guard let entries = try? fm.contentsOfDirectory(atPath: location.url.path) else { continue }
            for entry in entries where !entry.hasPrefix(".") {
                let lower = entry.lowercased()
                let stem = stem(of: entry).lowercased()
                let isMatch: Bool
                switch location.match {
                case .exact:
                    isMatch = (id.map { stem == $0 || stem.hasPrefix($0 + ".") } ?? false) || names.contains(stem)
                case .contains:
                    isMatch = id.map { lower.contains($0) } ?? false
                }
                if isMatch {
                    found.append((location.url.appendingPathComponent(entry), location.category))
                }
            }
        }

        // Drop duplicates and items nested inside another match.
        var seen = Set<String>()
        let unique = found.filter { seen.insert($0.0.standardizedFileURL.path).inserted }
        let paths = unique.map { $0.0.path }
        return unique
            .filter { item in !paths.contains { $0 != item.0.path && item.0.path.hasPrefix($0 + "/") } }
            .filter { $0.0.path != appURL.path }
            .map { RelatedFile(url: $0.0, category: $0.1, size: FileSizer.size(of: $0.0)) }
            .sorted { ($0.category, $1.size) < ($1.category, $0.size) }
    }
}

// MARK: - Caches & junk

enum CacheScanner {
    private struct Candidate {
        let url: URL
        let title: String
        let bundleID: String?
        let group: CleanGroup
    }

    static func scan() -> [CleanableItem] {
        var candidates: [Candidate] = []
        candidates += children(of: Paths.lib("Caches"), group: .appCaches)
        candidates += children(of: Paths.lib("Logs"), group: .logs)

        let developer: [(String, URL)] = [
            ("Xcode DerivedData", Paths.lib("Developer/Xcode/DerivedData")),
            ("iOS Device Support", Paths.lib("Developer/Xcode/iOS DeviceSupport")),
            ("watchOS Device Support", Paths.lib("Developer/Xcode/watchOS DeviceSupport")),
            ("Simulator Caches", Paths.lib("Developer/CoreSimulator/Caches")),
            ("npm cache", Paths.home(".npm/_cacache")),
            ("Gradle caches", Paths.home(".gradle/caches")),
            ("pnpm store", Paths.lib("pnpm/store")),
            ("~/.cache", Paths.home(".cache")),
        ]
        for (title, url) in developer where FileManager.default.fileExists(atPath: url.path) {
            candidates.append(Candidate(url: url, title: title, bundleID: nil, group: .developer))
        }

        // Measure folders in parallel; this is the slow part.
        var sizes = [Int64](repeating: 0, count: candidates.count)
        sizes.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: candidates.count) { i in
                buffer[i] = FileSizer.size(of: candidates[i].url)
            }
        }

        return zip(candidates, sizes)
            .filter { $0.1 > 0 }
            .map { CleanableItem(url: $0.0.url, title: $0.0.title, bundleID: $0.0.bundleID, size: $0.1, group: $0.0.group) }
            .sorted { $0.size > $1.size }
    }

    /// Apple-owned cache folders, including the ones without a "com.apple." prefix.
    private static let appleSystemCaches: Set<String> = [
        "cloudkit", "familycircle", "familycircled", "gamekit", "geoservices", "icloudmailagent",
        "jetpackcache", "passkit", "temporaryitems", "installation", "metadata", "applespell",
    ]

    private static func isAppleSystemCache(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("com.apple.") || appleSystemCaches.contains(lower)
    }

    private static func children(of dir: URL, group: CleanGroup) -> [Candidate] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }

        // Apple's own caches are protected by privacy controls (touching them triggers
        // permission prompts) and aren't safe to clean, so they're left alone.
        return entries.filter { !isAppleSystemCache($0.lastPathComponent) }.map { url in
            let entry = url.lastPathComponent
            let stem = RelatedFinder.stem(of: entry)
            if BundleID.looksLike(stem),
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: stem) {
                let name = FileManager.default.displayName(atPath: appURL.path)
                    .replacingOccurrences(of: ".app", with: "")
                return Candidate(url: url, title: name, bundleID: stem, group: group)
            }
            return Candidate(url: url, title: entry, bundleID: nil, group: group)
        }
    }
}

enum BundleID {
    static func looksLike(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty }) else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return parts.allSatisfy { $0.unicodeScalars.allSatisfy(allowed.contains) }
    }

    static func vendor(_ id: String) -> String {
        id.lowercased().split(separator: ".").prefix(2).joined(separator: ".")
    }
}

// MARK: - Leftovers of uninstalled apps

enum LeftoverScanner {
    private static let locations: [(URL, FileCategory)] = [
        (Paths.lib("Application Support"), .appSupport),
        (Paths.lib("Caches"), .caches),
        (Paths.lib("Preferences"), .preferences),
        (Paths.lib("Containers"), .containers),
        (Paths.lib("Logs"), .logs),
        (Paths.lib("Saved Application State"), .savedState),
        (Paths.lib("HTTPStorages"), .webData),
        (Paths.lib("WebKit"), .webData),
        (Paths.lib("Cookies"), .webData),
        (Paths.lib("Application Scripts"), .scripts),
    ]

    private static let ignoredPrefixes = ["com.apple.", "group.", "systemgroup.", "apple.", "com.microsoft.office"]

    static func scan(installedApps: [URL]) -> [LeftoverGroup] {
        let known = knownBundleIDs(in: installedApps)
        let vendors = Set(known.map(BundleID.vendor))
        var launchServicesCache: [String: Bool] = [:]

        func isOrphan(_ id: String) -> Bool {
            let lower = id.lowercased()
            if ignoredPrefixes.contains(where: lower.hasPrefix) { return false }
            if known.contains(lower) { return false }
            if known.contains(where: { lower.hasPrefix($0 + ".") || $0.hasPrefix(lower + ".") }) { return false }
            if vendors.contains(BundleID.vendor(lower)) { return false }
            if let cached = launchServicesCache[lower] { return cached }
            let orphan = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) == nil
            launchServicesCache[lower] = orphan
            return orphan
        }

        var groups: [String: [RelatedFile]] = [:]
        for (dir, category) in locations {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { continue }
            for entry in entries where !entry.hasPrefix(".") {
                let stem = RelatedFinder.stem(of: entry)
                guard BundleID.looksLike(stem), isOrphan(stem) else { continue }
                let url = dir.appendingPathComponent(entry)
                groups[stem.lowercased(), default: []]
                    .append(RelatedFile(url: url, category: category, size: FileSizer.size(of: url)))
            }
        }

        return groups
            .map { LeftoverGroup(bundleID: $0.value.first.map { RelatedFinder.stem(of: $0.url.lastPathComponent) } ?? $0.key,
                                 files: $0.value.sorted { $0.category < $1.category }) }
            .filter { $0.size > 0 }
            .sorted { $0.size > $1.size }
    }

    /// Bundle IDs of installed apps plus their embedded helpers, extensions and login items.
    private static func knownBundleIDs(in apps: [URL]) -> Set<String> {
        let embeddedDirs = ["Contents/PlugIns", "Contents/Library/LoginItems", "Contents/Helpers",
                            "Contents/XPCServices", "Contents/Library/LaunchServices", "Contents/Frameworks"]
        var ids = Set<String>()
        let fm = FileManager.default
        for app in apps {
            if let id = Bundle(url: app)?.bundleIdentifier { ids.insert(id.lowercased()) }
            for dir in embeddedDirs {
                let base = app.appendingPathComponent(dir)
                guard let entries = try? fm.contentsOfDirectory(atPath: base.path) else { continue }
                for entry in entries where ["app", "appex", "xpc"].contains((entry as NSString).pathExtension) {
                    if let id = Bundle(url: base.appendingPathComponent(entry))?.bundleIdentifier {
                        ids.insert(id.lowercased())
                    }
                }
            }
        }
        return ids
    }
}

// MARK: - Removal

enum Remover {
    struct Outcome {
        var removed: Set<URL> = []
        var failed: [URL] = []
    }

    /// Moves items to the Trash (or deletes them). Items that need extra privileges are
    /// retried through NSWorkspace, which shows the system authorization prompt.
    @MainActor
    static func remove(_ urls: [URL], permanently: Bool) async -> Outcome {
        var outcome = Outcome()
        let fm = FileManager.default
        for url in urls {
            do {
                if permanently {
                    try fm.removeItem(at: url)
                } else {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                }
                outcome.removed.insert(url)
            } catch {
                if !fm.fileExists(atPath: url.path) {
                    outcome.removed.insert(url)
                } else {
                    outcome.failed.append(url)
                }
            }
        }

        if !outcome.failed.isEmpty {
            let retry = outcome.failed
            let recycled: [URL: URL] = await withCheckedContinuation { continuation in
                NSWorkspace.shared.recycle(retry) { newURLs, _ in
                    continuation.resume(returning: newURLs)
                }
            }
            outcome.failed = retry.filter { url in
                if recycled[url] != nil || !fm.fileExists(atPath: url.path) {
                    outcome.removed.insert(url)
                    return false
                }
                return true
            }
        }
        return outcome
    }
}

// MARK: - System info

enum SystemInfo {
    static func disk() -> DiskInfo? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = v.volumeTotalCapacity,
              let available = v.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return DiskInfo(total: Int64(total), available: available)
    }

    /// Without Full Disk Access, protected folders such as ~/Library/Safari can't be listed.
    static var hasFullDiskAccess: Bool {
        let probes = [Paths.lib("Safari"), Paths.lib("Mail"), Paths.lib("Application Support/com.apple.TCC")]
        let existing = probes.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return true }
        return existing.contains { (try? FileManager.default.contentsOfDirectory(atPath: $0.path)) != nil }
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
