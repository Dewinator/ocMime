import SwiftUI

@main
struct OpenClawFaceApp: App {

    @StateObject private var gateway = GatewayService()
    @StateObject private var emotionRouter = EmotionRouter()
    @StateObject private var bonjourServer = BonjourServer()

    var body: some Scene {
        WindowGroup {
            ContentView(
                gateway: gateway,
                emotionRouter: emotionRouter,
                bonjourServer: bonjourServer
            )
            .frame(minWidth: 560, minHeight: 500)
            .background(Theme.backgroundPrimary)
            .onAppear {
                emotionRouter.subscribe(to: gateway, bonjourServer: bonjourServer)
                bonjourServer.start()
                gateway.autoConnect()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 560)
    }
}
