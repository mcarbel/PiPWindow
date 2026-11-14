import AppKit
import AVFoundation
import QuartzCore
import SwiftUI

struct SampleBufferVideoView: NSViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer

    func makeNSView(context: Context) -> VideoContainerNSView {
        let view = VideoContainerNSView(displayLayer: displayLayer)
        return view
    }

    func updateNSView(_ nsView: VideoContainerNSView, context: Context) {
        nsView.needsLayout = true
    }
}

final class VideoContainerNSView: NSView {
    private let videoLayer: AVSampleBufferDisplayLayer

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.videoLayer = displayLayer
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        self.layer?.addSublayer(videoLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = bounds
        CATransaction.commit()
    }
}

struct PiPContainerView: View {
    @ObservedObject var controller: PiPPanelController
    let displayLayer: AVSampleBufferDisplayLayer

    var body: some View {
        ZStack {
            SampleBufferVideoView(displayLayer: displayLayer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let errorMessage = controller.streamErrorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    Text("Capture interrupted")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // Hover HUD Overlay
            VStack(spacing: 0) {
                // Top Bar
                HStack(spacing: 8) {
                    Button {
                        controller.closePiP()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.18), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close Picture-in-Picture")

                    if let icon = controller.windowItem.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }

                    Text(controller.windowItem.displayTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    Button {
                        controller.activateSourceApp()
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Bring source window to front")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.75), .black.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()

                // Bottom Bar: Size presets, Aspect Ratio Lock, Cursor Toggle
                HStack(spacing: 8) {
                    // Size presets
                    HStack(spacing: 4) {
                        presetButton(label: "S", width: 320, tooltip: "Small (320px wide)")
                        presetButton(label: "M", width: 460, tooltip: "Medium (460px wide)")
                        presetButton(label: "L", width: 680, tooltip: "Large (680px wide)")
                    }
                    .padding(3)
                    .background(.black.opacity(0.55), in: Capsule())

                    Spacer()

                    // Cursor visibility toggle
                    Button {
                        controller.toggleCursor()
                    } label: {
                        Image(systemName: controller.showsCursor ? "cursorarrow.rays" : "cursorarrow.slash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(controller.showsCursor ? .cyan : .white.opacity(0.8))
                            .frame(width: 26, height: 26)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(controller.showsCursor ? "Cursor visible in PiP (Click to hide)" : "Cursor hidden in PiP (Click to show)")

                    // Aspect Ratio Lock toggle
                    Button {
                        controller.toggleAspectRatioLock()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: controller.isAspectRatioLocked ? "lock.fill" : "lock.open.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Aspect")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(controller.isAspectRatioLocked ? .green : .white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.55), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(controller.isAspectRatioLocked ? "Aspect Ratio Locked (Click to unlock)" : "Aspect Ratio Unlocked (Click to lock & snap)")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.0), .black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .foregroundStyle(.white)
            .opacity(controller.isHovering ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.16), value: controller.isHovering)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(controller.isHovering ? 0.35 : 0.14), lineWidth: 1)
        )
        .onHover { hovering in
            controller.isHovering = hovering
        }
    }

    private func presetButton(label: String, width: CGFloat, tooltip: String) -> some View {
        Button {
            controller.applyPresetWidth(width)
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .frame(width: 22, height: 20)
                .background(.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
