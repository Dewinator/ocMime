import Foundation
import Network

enum BonjourConstants {
    static let serviceType = "_openclawface._tcp"
    static let serviceName = "OpenClaw Face"

    /// Hard cap on a single framed payload (1 MB).
    /// Prevents a malformed or hostile header from making us wait forever
    /// for an absurd amount of data.
    static let maxFrameSize: Int = 1 * 1024 * 1024
}

// MARK: - Length-Prefixed Framing Protocol

/// Custom NWProtocolFramer: 4-byte big-endian length header + JSON payload.
///
/// Contract for `handleInput`:
/// - Return value = number of bytes the framer should accumulate before calling
///   us again. Returning 4 means "wake me when at least 4 more bytes are buffered."
/// - Returning 0 fails fast.
///
/// We never block on a payload bigger than `BonjourConstants.maxFrameSize`.
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
            var headerBytes = [UInt8](repeating: 0, count: 4)
            let headerParsed = framer.parseInput(minimumIncompleteLength: 4, maximumLength: 4) { buffer, _ in
                guard let buffer, buffer.count >= 4 else { return 0 }
                for i in 0..<4 { headerBytes[i] = buffer[i] }
                return 4
            }

            // Not enough data for the header yet — ask the framer to wake us
            // when at least 4 bytes are buffered.
            guard headerParsed else { return 4 }

            let length =
                (UInt32(headerBytes[0]) << 24) |
                (UInt32(headerBytes[1]) << 16) |
                (UInt32(headerBytes[2]) << 8)  |
                 UInt32(headerBytes[3])

            // Defensive: a 0-length frame is meaningless and an oversized frame
            // is either a bug or a hostile peer. Either way, we don't want to
            // park the connection waiting forever.
            guard length > 0, length <= UInt32(BonjourConstants.maxFrameSize) else {
                // Mark the connection broken so the higher level can reconnect.
                _ = framer.deliverInputNoCopy(length: 0, message: NWProtocolFramer.Message(definition: Self.definition), isComplete: true)
                return 0
            }

            let message = NWProtocolFramer.Message(definition: Self.definition)
            // deliverInputNoCopy returns false if the framer doesn't yet have
            // `length` bytes buffered. In that case the framer parks the data
            // and will re-invoke handleInput when more arrives, so just stop.
            if !framer.deliverInputNoCopy(length: Int(length), message: message, isComplete: true) {
                return Int(length)
            }
        }
    }

    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        var header = UInt32(messageLength).bigEndian
        framer.writeOutput(data: Data(bytes: &header, count: 4))
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            // Connection will surface the framing failure via stateUpdateHandler.
        }
    }
}
