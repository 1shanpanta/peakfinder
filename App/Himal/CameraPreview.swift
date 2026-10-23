import AVFoundation
import SwiftUI

/// What the PeakCore optics need to know about the running camera.
struct CameraLens: Sendable, Equatable {
    /// Field of view in degrees along the long side of the image.
    var longAxisFieldOfView: Double
    /// Long side over short side of the video image.
    var imageAspect: Double
}

struct CameraPreview: UIViewRepresentable {
    let onLens: (CameraLens) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.start(onLens: onLens)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        view.stop()
    }
}

/// Owns the capture session. Every touch of the session runs on one serial queue, which is what makes it safe to share.
private final class CameraSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "himal.camera")

    /// Starts the back camera. Returns its lens, or nil where there is no camera.
    func start() async -> CameraLens? {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.configureAndRun()) }
        }
    }

    func stop() {
        queue.async { self.session.stopRunning() }
    }

    private func configureAndRun() -> CameraLens? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return nil }
        session.beginConfiguration()
        session.sessionPreset = .high
        session.addInput(input)
        session.commitConfiguration()
        session.startRunning()
        // The preset picks the format, so the image shape is known only now. Video comes out landscape.
        let size = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        return CameraLens(
            longAxisFieldOfView: Double(device.activeFormat.videoFieldOfView),
            imageAspect: Double(max(size.width, size.height)) / Double(min(size.width, size.height))
        )
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private let camera = CameraSession()

    private var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass guarantees this type.
        layer as! AVCaptureVideoPreviewLayer
    }

    func start(onLens: @escaping (CameraLens) -> Void) {
        previewLayer.session = camera.session
        previewLayer.videoGravity = .resizeAspectFill
        Task {
            if let lens = await camera.start() { onLens(lens) }
        }
    }

    func stop() {
        camera.stop()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let angle: CGFloat = switch window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: 180
        case .landscapeRight: 0
        case .portraitUpsideDown: 270
        default: 90
        }
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}
