import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct PiPWindowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = WindowListViewModel()

    var body: some Scene {
        WindowGroup("PiPWindow — Select a Window") {
            ContentView(viewModel: viewModel)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 820, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Picture-in-Picture") {
                Button("Refresh Window List") {
                    Task {
                        await viewModel.refreshWindows()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Button("Close All PiP Windows") {
                    viewModel.closeAllPiP()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(viewModel.activePiPControllers.isEmpty)
            }
        }
    }
}
