import SwiftUI

@main
struct OpenClawFaceApp: App {

    @StateObject private var gateway = GatewayService()
    @StateObject private var emotionRouter = EmotionRouter()
    @StateObject private var bonjourServer = BonjourServer()
    @StateObject private var sensorRouter = SensorRouter()
    @StateObject private var agentTarget = AgentTargetService()

    var body: some Scene {
        WindowGroup {
            ContentView(
                gateway: gateway,
                emotionRouter: emotionRouter,
                bonjourServer: bonjourServer,
                sensorRouter: sensorRouter,
                agentTarget: agentTarget
            )
            .frame(minWidth: 560, minHeight: 500)
            .background(Theme.backgroundPrimary)
            .onAppear {
                sensorRouter.subscribe(to: bonjourServer, emotionRouter: emotionRouter, gateway: gateway, agentTarget: agentTarget)
                emotionRouter.subscribe(to: gateway, bonjourServer: bonjourServer, sensorRouter: sensorRouter, agentTarget: agentTarget)
                bonjourServer.start()
                gateway.autoConnect()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 600)
    }
}
