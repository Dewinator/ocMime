import Foundation
import Network

enum BonjourConstants {
    static let serviceType = "_openclawface._tcp"
    static let serviceName = "OpenClaw Face"
    static let framing = NWProtocolFramer.Options(definition: EmotionFramerProtocol.definition)
}

// MARK: - Length-Prefixed Framing Protocol

/// Custom NWProtocolFramer: 4-byte length header + JSON payload
/// Ensures complete messages arrive even over TCP streams
final class EmotionFramerProtocol: NWProtocolFramerImplementation {

    static let definition = NWProtocolFramer.Definition(implementation: EmotionFramerProtocol.self)
    static var label: String { "EmotionFramer" }

    required init(framer: NWProtocolFramer.Instance) {}

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .ready }
    func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
    func wakeup(framer: NWProtocolFramer.Instance) {}
    func cleanup(framer: NWProtocolFramer.Instance) {}

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var tempHeader = Data()
            let headerParsed = framer.parseInput(minimumIncompleteLength: 4, maximumLength: 4) { buffer, isComplete in
                if let buffer, buffer.count >= 4 {
                    tempHeader = Data(buffer.prefix(4))
                    return 4
                }
                return 0
            }

            guard headerParsed, tempHeader.count == 4 else { return 4 }

            let length = tempHeader.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian

            let message = NWProtocolFramer.Message(definition: Self.definition)
            _ = framer.deliverInputNoCopy(length: Int(length), message: message, isComplete: true)
        }
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        var header = UInt32(messageLength).bigEndian
        framer.writeOutput(data: Data(bytes: &header, count: 4))
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            // Framing error — connection will report it
        }
    }
}
