import AppKit
import AVFoundation
import CoreMedia
import CoreVideo
import QuartzCore
import ScreenCaptureKit

@MainActor
protocol WindowCaptureStreamDelegate: AnyObject {
    func captureStreamDidUpdateContentSize(_ size: CGSize)
    func captureStreamDidStop(error: Error?)
}

final class WindowCaptureStream: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let scWindow: SCWindow
    private let videoSampleBufferQueue = DispatchQueue(label: "com.pipwindow.SampleBufferQueue", qos: .userInteractive)

    let displayLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = NSColor.black.cgColor
        return layer
    }()

    weak var delegate: WindowCaptureStreamDelegate?

    private var lastReportedSize: CGSize = .zero
    private(set) var showsCursor: Bool = false

    init(window: SCWindow) {
        self.scWindow = window
        self.lastReportedSize = window.frame.size
        super.init()
    }

    @MainActor
    func start(showsCursor: Bool = false) async throws {
        self.showsCursor = showsCursor
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = makeStreamConfiguration(for: scWindow.frame.size, showsCursor: showsCursor)

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
        try await newStream.startCapture()
        self.stream = newStream
    }

    @MainActor
    func updateConfiguration(targetSize: CGSize? = nil, showsCursor: Bool? = nil) async {
        guard let stream = stream else { return }
        if let showsCursor = showsCursor {
            self.showsCursor = showsCursor
        }
        let baseSize = targetSize ?? (lastReportedSize.width > 0 ? lastReportedSize : scWindow.frame.size)
        let config = makeStreamConfiguration(for: baseSize, showsCursor: self.showsCursor)
        try? await stream.updateConfiguration(config)
    }

    @MainActor
    func stop() async {
        guard let currentStream = stream else { return }
        self.stream = nil
        try? await currentStream.stopCapture()
        displayLayer.flushAndRemoveImage()
    }

    private func makeStreamConfiguration(for windowSize: CGSize, showsCursor: Bool) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0

        // Capture at native Retina resolution of the source window (clamped to sensible bounds)
        let rawWidth = max(Int(windowSize.width * scaleFactor), 320)
        let rawHeight = max(Int(windowSize.height * scaleFactor), 200)

        // Ensure even dimensions for optimal hardware pipeline handling
        config.width = rawWidth + (rawWidth % 2)
        config.height = rawHeight + (rawHeight % 2)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
        config.queueDepth = 5
        config.scalesToFit = true
        config.showsCursor = showsCursor
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.displayP3

        return config
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen, sampleBuffer.isValid else { return }

        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first,
              let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete
        else {
            return
        }

        // Enqueue directly onto hardware-accelerated AVSampleBufferDisplayLayer
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)

        // Check if source window dimensions changed dynamically
        if let contentRectDict = attachments[SCStreamFrameInfo.contentRect],
           let contentRect = CGRect(dictionaryRepresentation: contentRectDict as! CFDictionary),
           contentRect.width > 10 && contentRect.height > 10 {
            let newSize = contentRect.size
            let widthDiff = abs(newSize.width - lastReportedSize.width)
            let heightDiff = abs(newSize.height - lastReportedSize.height)
            if widthDiff > 2 || heightDiff > 2 {
                lastReportedSize = newSize
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.delegate?.captureStreamDidUpdateContentSize(newSize)
                    await self.updateConfiguration(targetSize: newSize)
                }
            }
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.delegate?.captureStreamDidStop(error: error)
        }
    }
}
