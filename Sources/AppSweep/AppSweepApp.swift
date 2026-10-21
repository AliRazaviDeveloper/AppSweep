import SwiftUI

@main
struct AppSweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(\.layoutDirection, Self.layoutDirection)
                .frame(minWidth: 1000, minHeight: 660)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan") {
                Button("Rescan Everything") {
                    Task { await model.bootstrap() }
                }
                .keyboardShortcut("r")
            }
        }

        Settings {
            SettingsView()
                .environment(\.layoutDirection, Self.layoutDirection)
        }
    }
}

extension AppSweepApp {
    /// Mirrors the UI for right-to-left languages such as Persian.
    static var layoutDirection: LayoutDirection {
        let language = Locale.Language(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        return language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct SettingsView: View {
    @AppStorage("appLanguage") private var language = "system"
    @State private var needsRestart = false

    var body: some View {
        Form {
            Picker("Language", selection: $language) {
                Text("System").tag("system")
                Text(verbatim: "English").tag("en")
                Text(verbatim: "فارسی").tag("fa")
            }
            .onChange(of: language) { _, newValue in
                if newValue == "system" {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                } else {
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                }
                needsRestart = true
            }

            if needsRestart {
                HStack {
                    Text("Restart AppSweep to apply the new language.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restart Now", action: relaunch)
                }
            }

            LabeledContent("Full Disk Access") {
                Button("Open Privacy Settings") { SystemInfo.openFullDiskAccessSettings() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .padding(.vertical, 8)
    }

    private func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
