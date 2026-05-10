import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct TokenShedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var setupModel = SetupViewModel()

    var body: some Scene {
        WindowGroup {
            OnboardingView(model: setupModel)
                .task {
                    await setupModel.refresh()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .help) {
                Button("TokenShed Help") {
                    SetupLinks.openProjectReadme()
                }
            }

            CommandGroup(after: .appInfo) {
                Button("Refresh Status") {
                    Task { await setupModel.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
