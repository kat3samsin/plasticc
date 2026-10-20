import AVFoundation

enum CameraError: Error { case notReady, noImage }

/// The back wide camera, fixed like a disposable's lens: auto focus and exposure, flash on or off, nothing else.
final class LiveCamera: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "plasticc.session")
    private let photoOutput = AVCapturePhotoOutput()
    /// Session queue only.
    private var isConfigured = false
    private var rotation: AVCaptureDevice.RotationCoordinator?

    private let lock = NSLock()
    /// Each capture's continuation, by settings ID. Guarded by `lock`.
    private var pending: [Int64: CheckedContinuation<Data, Error>] = [:]

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

    func capture(flash: Bool) async throws -> Data {
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

                let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                settings.flashMode = flash && photoOutput.supportedFlashModes.contains(.on) ? .on : .off
                settings.photoQualityPrioritization = .balanced
                lock.withLock { pending[settings.uniqueID] = continuation }
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
        }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        photoOutput.maxPhotoQualityPrioritization = .balanced
        session.commitConfiguration()
    }

    private func finish(_ id: Int64, with result: Result<Data, Error>) {
        lock.withLock { pending.removeValue(forKey: id) }?.resume(with: result)
    }
}

// Declared apart from the class so the class isn't inferred to be main-actor isolated;
// its work runs on the session queue and the photo output's delegate queue.
extension LiveCamera: PhotoCapturing {}

extension LiveCamera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        if let error {
            finish(id, with: .failure(error))
        } else if let data = photo.fileDataRepresentation() {
            finish(id, with: .success(data))
        } else {
            finish(id, with: .failure(CameraError.noImage))
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // Only reached with a continuation left when no photo was delivered.
        finish(resolvedSettings.uniqueID, with: .failure(error ?? CameraError.noImage))
    }
}
