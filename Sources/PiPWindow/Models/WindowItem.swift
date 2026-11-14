import AppKit
import ScreenCaptureKit

struct WindowItem: Identifiable, Hashable {
    let id: CGWindowID
    let scWindow: SCWindow
    let title: String
    let appName: String
    let bundleIdentifier: String
    let appIcon: NSImage?
    let frame: CGRect
    let isOnScreen: Bool

    var aspectRatio: CGFloat {
        guard frame.height > 0 else { return 16.0 / 9.0 }
        return frame.width / frame.height
    }

    var dimensionsText: String {
        "\(Int(frame.width)) × \(Int(frame.height))"
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appName : trimmed
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WindowItem, rhs: WindowItem) -> Bool {
        lhs.id == rhs.id
    }
}
