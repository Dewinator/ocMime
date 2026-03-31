import AVFoundation
import Foundation
import SoundAnalysis

@MainActor
final class SoundAnalysisService: ObservableObject {

    @Published var isActive = false
    @Published var lastSoundType: String?
    @Published var lastConfidence: Double = 0
    @Published var lastError: String?

    var onSoundDetected: ((String, Double) -> Void)?  // (soundType, confidence)

    private var audioEngine: AVAudioEngine?
    private var analyzer: SNAudioStreamAnalyzer?
    private let analysisQueue = DispatchQueue(label: "net.eab-solutions.openclawdisplay.sound", qos: .userInitiated)

    /// Minimum confidence threshold for reporting a sound
    private let confidenceThreshold: Double = 0.6

    /// Sound types we care about (subset of the 300+ available)
    private let relevantSounds: Set<String> = [
        "speech", "knock", "door", "doorbell",
        "clapping", "finger_snapping",
        "footsteps", "laughter",
        "alarm", "bell", "buzzer",
        "cough", "whistling", "singing"
    ]

    // MARK: - Start / Stop

    func start() {
        guard !isActive else { return }

        #if os(iOS)
        do {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            let streamAnalyzer = SNAudioStreamAnalyzer(format: format)
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            let observer = SoundObserver(service: self)
            try streamAnalyzer.add(request, withObserver: observer)

            inputNode.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak streamAnalyzer] buffer, time in
                streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }

            engine.prepare()
            try engine.start()

            self.audioEngine = engine
            self.analyzer = streamAnalyzer
            isActive = true
            lastError = nil
        } catch {
            lastError = "Sound analysis failed: \(error.localizedDescription)"
            isActive = false
        }
        #endif
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        analyzer = nil
        isActive = false
    }

    // MARK: - Result Processing (called from observer)

    nonisolated func handleClassification(_ classification: SNClassificationResult) {
        // Find the most confident relevant sound above threshold
        let relevant = classification.classifications
            .filter { Double($0.confidence) >= confidenceThreshold }
            .filter { relevantSounds.contains($0.identifier) }
            .max(by: { $0.confidence < $1.confidence })

        guard let match = relevant else { return }

        let soundType = match.identifier
        let confidence = Double(match.confidence)

        Task { @MainActor in
            lastSoundType = soundType
            lastConfidence = confidence
            onSoundDetected?(soundType, confidence)
        }
    }
}

// MARK: - Sound Observer

#if os(iOS)
private final class SoundObserver: NSObject, SNResultsObserving, @unchecked Sendable {

    private weak var service: SoundAnalysisService?

    init(service: SoundAnalysisService) {
        self.service = service
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classification = result as? SNClassificationResult else { return }
        service?.handleClassification(classification)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        Task { @MainActor in
            service?.lastError = "Classification error: \(error.localizedDescription)"
        }
    }
}
#endif
