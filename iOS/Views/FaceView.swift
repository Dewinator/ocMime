import SwiftUI

enum DisplayMode {
    case custom
    case abstract
}

struct FaceView: View {

    @ObservedObject var client: BonjourClient
    // Animators are deliberately NOT @ObservedObject: they mutate internal
    // state every frame. Their views (CustomFaceView / AbstractFaceView)
    // drive redraw via TimelineView at their own cadence. Observing them
    // here would recompute this whole view tree on every animation tick.
    let animator: EmotionAnimator
    let abstractAnimator: AbstractAnimator
    @ObservedObject var ttsService: TTSService
    @ObservedObject var sttService: STTService
    @ObservedObject var presenceService: PresenceService
    @ObservedObject var soundService: SoundAnalysisService
    @Binding var displayMode: DisplayMode
    @Binding var customConfig: CustomAvatarConfig
    @Binding var abstractConfig: AbstractAvatarConfig

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch displayMode {
            case .custom:
                CustomFaceView(config: customConfig, animator: animator)
                    .ignoresSafeArea()
            case .abstract:
                AbstractFaceView(config: abstractConfig, animator: abstractAnimator)
                    .ignoresSafeArea()
            }

            // Status indicators
            VStack {
                HStack {
                    // Sensor status (top left) — subtle dots
                    HStack(spacing: 3) {
                        if sttService.isListening {
                            Circle()
                                .fill(Color.cyan.opacity(0.6))
                                .frame(width: 5, height: 5)
                        }
                        if presenceService.isActive {
                            Circle()
                                .fill(presenceService.personDetected ? Color.orange.opacity(0.6) : Color.purple.opacity(0.4))
                                .frame(width: 5, height: 5)
                        }
                        if soundService.isActive {
                            Circle()
                                .fill(Color.blue.opacity(0.4))
                                .frame(width: 5, height: 5)
                        }
                        if ttsService.isSpeaking {
                            Circle()
                                .fill(Color.green.opacity(0.6))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .padding(8)

                    Spacer()

                    // Connection status (top right)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        if !client.connectionState.isConnected {
                            Text(client.connectionState.displayText)
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(8)
                }
                Spacer()
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear {
            animator.reduceMotion = reduceMotion
        }
        .onChange(of: reduceMotion) { _, newValue in
            animator.reduceMotion = newValue
        }
    }

    private var statusColor: Color {
        switch client.connectionState {
        case .connected:    return .green.opacity(0.6)
        case .connecting:   return .yellow.opacity(0.6)
        case .disconnected: return .gray.opacity(0.4)
        case .error:        return .red.opacity(0.6)
        }
    }
}
