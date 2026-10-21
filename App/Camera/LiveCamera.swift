import AVFoundation
import ImageIO
import os
import PlasticcCore

enum CameraError: Error { case notReady, noImage }

/// The back wide camera, fixed like a disposable's lens: auto focus and exposure, flash on or off, nothing else.
/// Frames are the iPhone's own photo at the sensor's full resolution (48 MP on recent iPhones), which the lab
/// downsamples to a 24 MP print.
final class LiveCamera: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "plasticc.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let log = Logger(subsystem: "com.katre.plasticc", category: "camera")
    /// Session queue only.
    private var isConfigured = false
    private var rotation: AVCaptureDevice.RotationCoordinator?
    /// The largest photo the camera can take; session queue only.
    private var fullSize: CMVideoDimensions?

    private struct Pending {
        let continuation: CheckedContinuation<Capture, Error>
        let fileExtension: String
    }

    private let lock = NSLock()
    /// Guarded by `lock`, keyed by settings ID.
    private var pending: [Int64: Pending] = [:]

    func start() async -> Bool {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        sessionQueue.async { [self] in
            if !isConfigured {
                configure()
                isConfigured = true
            }
            if !session.isRunning { session.startRunning() }
        }
        return true
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capture(flash: Bool) async throws -> Capture {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                guard session.isRunning,
                      let connection = photoOutput.connection(with: .video),
                      connection.isEnabled, connection.isActive else {
                    continuation.resume(throwing: CameraError.notReady)
                    return
                }
                // Level with the horizon however the phone is held, so a sideways shot is a landscape print.
                let angle = rotation?.videoRotationAngleForHorizonLevelCapture ?? 90
                if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }

                // HEIF keeps a 48 MP frame to a few megabytes.
                let hevc = photoOutput.availablePhotoCodecTypes.contains(.hevc)
                let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: hevc ? AVVideoCodecType.hevc : .jpeg])
                settings.flashMode = flash && photoOutput.supportedFlashModes.contains(.on) ? .on : .off
                settings.photoQualityPrioritization = .balanced
                if let fullSize { settings.maxPhotoDimensions = fullSize }
                lock.withLock { pending[settings.uniqueID] = Pending(continuation: continuation, fileExtension: hevc ? "heic" : "jpg") }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    /// Session queue only.
    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            fullSize = device.activeFormat.supportedMaxPhotoDimensions.max { $0.width * $0.height < $1.width * $1.height }
        }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if let fullSize { photoOutput.maxPhotoDimensions = fullSize }
        photoOutput.maxPhotoQualityPrioritization = .balanced
        session.commitConfiguration()
        log.info("Camera ready at \(self.fullSize.map { "\($0.width)×\($0.height)" } ?? "default size")")
    }

    private func finish(_ id: Int64, with result: (String) -> Result<Capture, Error>) {
        guard let entry = lock.withLock({ pending.removeValue(forKey: id) }) else { return }
        entry.continuation.resume(with: result(entry.fileExtension))
    }
}

// Declared apart from the class so the class isn't inferred to be main-actor isolated;
// its work runs on the session queue and the photo output's delegate queue.
extension LiveCamera: PhotoCapturing {}

extension LiveCamera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        if let error {
            finish(id) { _ in .failure(error) }
        } else if let data = photo.fileDataRepresentation() {
            let ev = Self.sceneEV100(photo.metadata)
            finish(id) { .success(Capture(data: data, sceneEV100: ev, fileExtension: $0)) }
        } else {
            finish(id) { _ in .failure(CameraError.noImage) }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // Only reached with a continuation left when no photo was delivered.
        finish(resolvedSettings.uniqueID) { _ in .failure(error ?? CameraError.noImage) }
    }

    /// EV at ISO 100 from the frame's EXIF.
    private static func sceneEV100(_ metadata: [String: Any]) -> Double? {
        guard let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let time = exif[kCGImagePropertyExifExposureTime as String] as? Double, time > 0,
              let aperture = exif[kCGImagePropertyExifFNumber as String] as? Double, aperture > 0,
              let iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Double])?.first, iso > 0 else { return nil }
        return log2(aperture * aperture / time) - log2(iso / 100)
    }
}
