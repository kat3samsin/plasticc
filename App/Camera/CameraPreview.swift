import AVFoundation
import SwiftUI

/// The live finder: the camera feed, upright for the portrait-only screen.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Which camera feeds it; a swap rebuilds the connection, which then needs turning upright again.
    let front: Bool

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        // The new connection appears once the session has reconfigured.
        for delay in [0.2, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { view.setNeedsLayout() }
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            // The connection exists once the session is running; the screen never rotates, so portrait is enough.
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}
