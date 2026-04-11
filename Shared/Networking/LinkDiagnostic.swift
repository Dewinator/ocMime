import Foundation

/// One entry in the Bonjour link diagnostics log.
/// Both the macOS server and the iOS client publish a rolling buffer of these
/// so the user can actually see what's happening on the wire.
struct LinkDiagnostic: Identifiable, Equatable {
    enum Level: String {
        case info, warning, error
    }

    let id = UUID()
    let level: Level
    let message: String
    let timestamp: Date
}
