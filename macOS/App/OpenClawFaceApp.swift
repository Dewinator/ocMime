import SwiftUI

@main
struct OpenClawFaceApp: App {

    @StateObject private var gateway = GatewayService()
    @StateObject private var emotionRouter = EmotionRouter()
    @StateObject private var bonjourServer = BonjourServer()
    @StateObject private var sensorRouter = SensorRouter()

    var body: some Scene {
        WindowGroup {
            ContentView(
                gateway: gateway,
                emotionRouter: emotionRouter,
                bonjourServer: bonjourServer,
                sensorRouter: sensorRouter
            )
            .frame(minWidth: 560, minHeight: 500)
            .background(Theme.backgroundPrimary)
            .onAppear {
                emotionRouter.subscribe(to: gateway, bonjourServer: bonjourServer)
                sensorRouter.subscribe(to: bonjourServer, emotionRouter: emotionRouter, gateway: gateway)
                bonjourServer.start()
                gateway.autoConnect()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 560)
    }
}
