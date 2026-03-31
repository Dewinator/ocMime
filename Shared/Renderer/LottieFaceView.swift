import Lottie
import SwiftUI

#if os(iOS)
import UIKit

struct LottieFaceView: UIViewRepresentable {

    @ObservedObject var engine: LottieAnimationEngine

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.contentMode = .scaleAspectFit
        view.backgroundBehavior = .pauseAndRestore
        view.backgroundColor = .black
        view.loopMode = .loop
        if let anim = engine.animationSource {
            view.animation = anim
            playSegment(view: view, state: engine.currentState)
        }
        return view
    }

    func updateUIView(_ view: LottieAnimationView, context: Context) {
        // Avatar changed?
        if view.animation !== engine.animationSource, let anim = engine.animationSource {
            view.animation = anim
        }
        playSegment(view: view, state: engine.currentState)
    }

    private func playSegment(view: LottieAnimationView, state: EmotionState) {
        let start = AnimationFrameTime(state.lottieStartFrame)
        let end = AnimationFrameTime(state.lottieEndFrame)
        view.loopMode = .loop
        view.animationSpeed = state.animationSpeed
        view.play(fromFrame: start, toFrame: end, loopMode: .loop)
    }
}

#elseif os(macOS)
import AppKit

struct LottieFaceView: NSViewRepresentable {

    @ObservedObject var engine: LottieAnimationEngine

    func makeNSView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.contentMode = .scaleAspectFit
        view.backgroundBehavior = .pauseAndRestore
        view.loopMode = .loop
        if let anim = engine.animationSource {
            view.animation = anim
            playSegment(view: view, state: engine.currentState)
        }
        return view
    }

    func updateNSView(_ view: LottieAnimationView, context: Context) {
        if view.animation !== engine.animationSource, let anim = engine.animationSource {
            view.animation = anim
        }
        playSegment(view: view, state: engine.currentState)
    }

    private func playSegment(view: LottieAnimationView, state: EmotionState) {
        let start = AnimationFrameTime(state.lottieStartFrame)
        let end = AnimationFrameTime(state.lottieEndFrame)
        view.loopMode = .loop
        view.animationSpeed = state.animationSpeed
        view.play(fromFrame: start, toFrame: end, loopMode: .loop)
    }
}
#endif

// MARK: - Speed per Emotion

extension EmotionState {
    var animationSpeed: CGFloat {
        switch self {
        case .idle:       return 0.8
        case .thinking:   return 1.0
        case .focused:    return 0.6
        case .responding: return 1.5
        case .error:      return 2.0
        case .success:    return 1.0
        case .listening:  return 0.8
        case .sleeping:   return 0.4
        }
    }
}
