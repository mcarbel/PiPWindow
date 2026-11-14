import AppKit
import QuartzCore
import ScreenCaptureKit
import SwiftUI

final class PiPPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PiPPanelController: NSObject, ObservableObject, NSWindowDelegate, WindowCaptureStreamDelegate {
    let windowItem: WindowItem
    private var panel: PiPPanel?
    private var captureStream: WindowCaptureStream?

    @Published var isAspectRatioLocked: Bool = true
    @Published var showsCursor: Bool = false
    @Published var isHovering: Bool = false
    @Published var sourceSize: CGSize
    @Published var streamErrorMessage: String?

    var onClose: (() -> Void)?

    init(windowItem: WindowItem) {
        self.windowItem = windowItem
        self.sourceSize = windowItem.frame.size
        super.init()
    }

    func showAndStartCapture() async {
        let stream = WindowCaptureStream(window: windowItem.scWindow)
        stream.delegate = self
        self.captureStream = stream

        let initialRect = calculateInitialFrame(for: windowItem.frame.size)
        let panel = PiPPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.minSize = NSSize(width: 200, height: 112)
        panel.contentAspectRatio = windowItem.frame.size
        panel.delegate = self
        panel.title = "PiP — \(windowItem.displayTitle)"

        let rootView = PiPContainerView(
            controller: self,
            displayLayer: stream.displayLayer
        )
        let hostingView = FirstMouseHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: initialRect.size)
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.panel = panel

        do {
            try await stream.start(showsCursor: showsCursor)
        } catch {
            self.streamErrorMessage = error.localizedDescription
        }
    }

    func closePiP() {
        let streamToStop = captureStream
        captureStream = nil
        if let panel = panel {
            panel.delegate = nil
            panel.orderOut(nil)
            self.panel = nil
        }
        Task {
            await streamToStop?.stop()
        }
        onClose?()
    }

    func toggleAspectRatioLock() {
        isAspectRatioLocked.toggle()
        guard let panel = panel else { return }
        if isAspectRatioLocked {
            snapToSourceAspectRatio(animated: true)
            panel.contentAspectRatio = sourceSize
        } else {
            panel.resizeIncrements = NSSize(width: 1, height: 1)
        }
    }

    func toggleCursor() {
        showsCursor.toggle()
        Task {
            await captureStream?.updateConfiguration(showsCursor: showsCursor)
        }
    }

    func applyPresetWidth(_ targetWidth: CGFloat) {
        guard let panel = panel else { return }
        let ratio = max(sourceSize.width / max(sourceSize.height, 1), 0.25)
        let targetHeight = round(targetWidth / ratio)
        var frame = panel.frame
        let centerX = frame.midX
        let centerY = frame.midY
        frame.size = NSSize(width: targetWidth, height: targetHeight)
        frame.origin = NSPoint(x: round(centerX - targetWidth / 2), y: round(centerY - targetHeight / 2))

        if let screenFrame = (panel.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = max(screenFrame.minX + 12, min(frame.origin.x, screenFrame.maxX - frame.width - 12))
            frame.origin.y = max(screenFrame.minY + 12, min(frame.origin.y, screenFrame.maxY - frame.height - 12))
        }

        panel.setFrame(frame, display: true, animate: true)
        if isAspectRatioLocked {
            panel.contentAspectRatio = sourceSize
        }
    }

    func activateSourceApp() {
        guard let pid = windowItem.scWindow.owningApplication?.processID else { return }
        if let runningApp = NSRunningApplication(processIdentifier: pid) {
            runningApp.activate()
        }
    }

    private func snapToSourceAspectRatio(animated: Bool) {
        guard let panel = panel, sourceSize.width > 0, sourceSize.height > 0 else { return }
        let aspect = sourceSize.width / sourceSize.height
        var frame = panel.frame
        let newWidth = frame.width
        let newHeight = round(newWidth / aspect)
        let deltaH = newHeight - frame.height
        frame.size.height = newHeight
        frame.origin.y -= deltaH / 2.0
        panel.setFrame(frame, display: true, animate: animated)
    }

    private func calculateInitialFrame(for windowSize: CGSize) -> NSRect {
        let aspect = windowSize.height > 0 ? (windowSize.width / windowSize.height) : (16.0 / 9.0)
        let defaultWidth: CGFloat = 460
        let clampedWidth = max(260, min(defaultWidth, 640))
        let calculatedHeight = round(clampedWidth / max(aspect, 0.3))

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let padding: CGFloat = 28
        let originX = screenFrame.maxX - clampedWidth - padding
        let originY = screenFrame.minY + padding

        return NSRect(x: originX, y: originY, width: clampedWidth, height: calculatedHeight)
    }

    // MARK: - WindowCaptureStreamDelegate

    func captureStreamDidUpdateContentSize(_ size: CGSize) {
        self.sourceSize = size
        if isAspectRatioLocked, let panel = panel {
            snapToSourceAspectRatio(animated: true)
            panel.contentAspectRatio = size
        }
    }

    func captureStreamDidStop(error: Error?) {
        closePiP()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        closePiP()
    }
}

/// Hosting view that accepts first mouse events so buttons in the floating PiP HUD respond immediately on first click.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
