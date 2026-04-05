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
            } else if let error = engine.loadError {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("[RIVE]")
                        .font(Theme.Font.headline)
                        .foregroundStyle(Theme.textTertiary)
                    Text(error)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text(".riv Datei im Rive Editor erstellen")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.textTertiary)
                    Text("und in Shared/RiveAssets/ ablegen")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.textTertiary)
                }
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("[RIVE]")
                        .font(Theme.Font.headline)
                        .foregroundStyle(Theme.textTertiary)
                    Text("Kein Avatar geladen")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }
}
