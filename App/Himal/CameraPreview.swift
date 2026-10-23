import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let onFieldOfView: (Double) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.start(onFieldOfView: onFieldOfView)
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

    /// Starts the back camera. Returns its field of view along the long side, or nil where there is no camera.
    func start() async -> Double? {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.configureAndRun()) }
        }
    }

    func stop() {
        queue.async { self.session.stopRunning() }
    }

    private func configureAndRun() -> Double? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return nil }
        session.beginConfiguration()
        session.sessionPreset = .high
        session.addInput(input)
        session.commitConfiguration()
        session.startRunning()
        return Double(device.activeFormat.videoFieldOfView)
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private let camera = CameraSession()

    private var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass guarantees this type.
        layer as! AVCaptureVideoPreviewLayer
    }

    func start(onFieldOfView: @escaping (Double) -> Void) {
        previewLayer.session = camera.session
        previewLayer.videoGravity = .resizeAspectFill
        Task {
            if let fieldOfView = await camera.start() { onFieldOfView(fieldOfView) }
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
