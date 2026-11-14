import AppKit
import CoreGraphics
import ScreenCaptureKit
import SwiftUI

@MainActor
final class WindowListViewModel: ObservableObject {
    @Published var windows: [WindowItem] = []
    @Published var thumbnails: [CGWindowID: NSImage] = [:]
    @Published var searchText: String = ""
    @Published var onScreenOnly: Bool = true
    @Published var hasPermission: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var activePiPControllers: [CGWindowID: PiPPanelController] = [:]

    private let excludedBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.WindowManager",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.systemuiserver",
        "com.apple.Spotlight",
        "com.apple.loginwindow"
    ]

    var filteredWindows: [WindowItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return windows }
        return windows.filter { item in
            item.displayTitle.lowercased().contains(query) ||
            item.appName.lowercased().contains(query)
        }
    }

    init() {
        checkPermissionAndRefresh()
    }

    func checkPermissionAndRefresh() {
        hasPermission = CGPreflightScreenCaptureAccess()
        Task {
            await refreshWindows()
        }
    }

    func requestPermission() {
        _ = CGRequestScreenCaptureAccess()
        Task {
            await refreshWindows()
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshWindows() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: onScreenOnly
            )
            hasPermission = true

            let currentPID = ProcessInfo.processInfo.processIdentifier

            let discovered: [WindowItem] = content.windows.compactMap { scWindow in
                guard let app = scWindow.owningApplication else { return nil }
                // Exclude our own app windows & panels
                if app.processID == currentPID { return nil }
                // Exclude system chrome / menu bar items
                if excludedBundleIDs.contains(app.bundleIdentifier) { return nil }
                // Exclude tiny utility or invisible windows
                guard scWindow.frame.width >= 120, scWindow.frame.height >= 80 else { return nil }
                // Exclude window layer != 0 (menu popups, status items, overlays)
                guard scWindow.windowLayer == 0 else { return nil }

                let appName = app.applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = (scWindow.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if appName.isEmpty && title.isEmpty { return nil }

                let runningApp = NSRunningApplication(processIdentifier: app.processID)
                let icon = runningApp?.icon

                return WindowItem(
                    id: scWindow.windowID,
                    scWindow: scWindow,
                    title: title,
                    appName: appName.isEmpty ? "Application" : appName,
                    bundleIdentifier: app.bundleIdentifier,
                    appIcon: icon,
                    frame: scWindow.frame,
                    isOnScreen: scWindow.isOnScreen
                )
            }

            // Sort on-screen windows first, then by application name and title
            self.windows = discovered.sorted { lhs, rhs in
                if lhs.isOnScreen != rhs.isOnScreen {
                    return lhs.isOnScreen && !rhs.isOnScreen
                }
                let appCompare = lhs.appName.localizedCaseInsensitiveCompare(rhs.appName)
                if appCompare != .orderedSame {
                    return appCompare == .orderedAscending
                }
                return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
            }

            // Capture lightweight thumbnails in background for macOS 14+
            if #available(macOS 14.0, *) {
                await loadThumbnails(for: self.windows)
            }
        } catch {
            hasPermission = CGPreflightScreenCaptureAccess()
            errorMessage = "Screen Recording permission is required to capture application windows."
        }
    }

    @available(macOS 14.0, *)
    private func loadThumbnails(for items: [WindowItem]) async {
        for item in items {
            let filter = SCContentFilter(desktopIndependentWindow: item.scWindow)
            let config = SCStreamConfiguration()
            let aspect = max(item.aspectRatio, 0.3)
            config.width = 360
            config.height = max(Int(360.0 / aspect), 120)
            config.scalesToFit = true
            config.showsCursor = false

            if let cgImage = try? await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            ) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                self.thumbnails[item.id] = nsImage
            }
        }
    }

    func togglePiP(for item: WindowItem) {
        if let existing = activePiPControllers[item.id] {
            existing.closePiP()
            activePiPControllers.removeValue(forKey: item.id)
        } else {
            startPiP(for: item)
        }
    }

    func startPiP(for item: WindowItem) {
        if let existing = activePiPControllers[item.id] {
            existing.closePiP()
        }

        let controller = PiPPanelController(windowItem: item)
        controller.onClose = { [weak self] in
            self?.activePiPControllers.removeValue(forKey: item.id)
        }
        activePiPControllers[item.id] = controller

        Task {
            await controller.showAndStartCapture()
        }
    }

    func closeAllPiP() {
        let controllers = Array(activePiPControllers.values)
        activePiPControllers.removeAll()
        for controller in controllers {
            controller.closePiP()
        }
    }
}
