import SwiftUI

enum DisplayMode {
    case lottie
    case custom
    case rive
}

struct FaceView: View {

    @ObservedObject var engine: LottieAnimationEngine
    @ObservedObject var riveEngine: RiveAnimationEngine
    @ObservedObject var client: BonjourClient
    @ObservedObject var animator: EmotionAnimator
    @Binding var displayMode: DisplayMode
    @Binding var customConfig: CustomAvatarConfig

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch displayMode {
            case .lottie:
                LottieFaceView(engine: engine)
                    .ignoresSafeArea()
            case .custom:
                CustomFaceView(config: customConfig, animator: animator)
                    .ignoresSafeArea()
            case .rive:
                RiveFaceView(engine: riveEngine)
                    .ignoresSafeArea()
            }

            // Subtiler Verbindungsstatus oben rechts
            VStack {
                HStack {
                    Spacer()
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
