import SwiftUI
import RiveRuntime

struct RiveFaceView: View {

    @ObservedObject var engine: RiveAnimationEngine

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let viewModel = engine.viewModel {
                viewModel.view()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No Rive file loaded")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
    }
}
