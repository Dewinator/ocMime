@preconcurrency import AVFoundation
import Foundation
import Vision

@MainActor
final class PresenceService: ObservableObject {

    @Published var isActive = false
    @Published var personDetected = false
    @Published var personCount = 0
    @Published var lastConfidence: Double = 0
    @Published var lastError: String?

    var onPresenceChanged: ((Bool, Int, Double) -> Void)?  // (detected, count, confidence)

    private var captureSession: AVCaptureSession?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "net.eab-solutions.openclawdisplay.presence", qos: .userInitiated)
    private nonisolated(unsafe) var lastProcessTime: Date = .distantPast
    private let processInterval: TimeInterval = 0.5  // Process every 500ms (2fps for presence)

    // Debounce: require multiple consecutive frames to change state
    private var consecutiveDetections = 0
    private var consecutiveAbsences = 0
    private let detectionThreshold = 3    // 3 frames with person = person entered
    private let absenceThreshold = 6      // 6 frames without person = person left

    // MARK: - Start / Stop

    func start() {
        guard !isActive else { return }

        #if os(iOS)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.lastError = "Camera access denied"
                    }
                }
            }
        default:
            lastError = "Camera access denied"
            return
        }
        #endif
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        isActive = false
        personDetected = false
        personCount = 0
        consecutiveDetections = 0
        consecutiveAbsences = 0
    }

    // MARK: - Capture Setup

    private func setupCaptureSession() {
        #if os(iOS)
        let session = AVCaptureSession()
        session.sessionPreset = .low  // Low resolution is enough for person detection

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            lastError = "No front camera available"
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            lastError = "Camera input failed: \(error.localizedDescription)"
            return
        }

        videoOutput.setSampleBufferDelegate(
            PresenceVideoDelegate(service: self),
            queue: processingQueue
        )
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        self.captureSession = session

        processingQueue.async {
            session.startRunning()
        }

        isActive = true
        lastError = nil
        #endif
    }

    // MARK: - Vision Processing (called from delegate on processingQueue)

    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        // Only process at desired interval
        guard now.timeIntervalSince(lastProcessTime) >= processInterval else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanRectanglesRequest { [weak self] request, error in
            guard let self else { return }

            let results = request.results as? [VNHumanObservation] ?? []
            let count = results.count
            let detected = count > 0
            let confidence = results.map(\.confidence).max().map(Double.init) ?? 0

            Task { @MainActor in
                self.updatePresence(detected: detected, count: count, confidence: confidence)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }

    private func updatePresence(detected: Bool, count: Int, confidence: Double) {
        if detected {
            consecutiveDetections += 1
            consecutiveAbsences = 0
        } else {
            consecutiveAbsences += 1
            consecutiveDetections = 0
        }

        let previouslyDetected = personDetected

        if !previouslyDetected && consecutiveDetections >= detectionThreshold {
            personDetected = true
            personCount = count
            lastConfidence = confidence
            onPresenceChanged?(true, count, confidence)
        } else if previouslyDetected && consecutiveAbsences >= absenceThreshold {
            personDetected = false
            personCount = 0
            lastConfidence = confidence
            onPresenceChanged?(false, 0, confidence)
        } else if previouslyDetected && detected {
            // Update count while person is present
            personCount = count
            lastConfidence = confidence
        }
    }
}

// MARK: - Video Delegate (bridges to nonisolated processing)

#if os(iOS)
private final class PresenceVideoDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    private weak var service: PresenceService?

    init(service: PresenceService) {
        self.service = service
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        service?.processFrame(sampleBuffer)
    }
}
#endif
