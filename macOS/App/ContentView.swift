import SwiftUI

struct ContentView: View {

    @ObservedObject var gateway: GatewayService
    @ObservedObject var emotionRouter: EmotionRouter
    @ObservedObject var bonjourServer: BonjourServer
    @ObservedObject var sensorRouter: SensorRouter

    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "BRIDGE"
        case avatar    = "AVATAR"
        case sensor    = "SENSOR"
        case skill     = "SKILL"
        case settings  = "CONFIG"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text("[\(tab.rawValue)]")
                            .font(Theme.Font.captionBold)
                            .foregroundStyle(selectedTab == tab ? Theme.backgroundPrimary : Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(selectedTab == tab ? Theme.accent : Theme.backgroundSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Theme.backgroundSecondary)

            switch selectedTab {
            case .dashboard:
                DashboardView(
                    gateway: gateway,
                    emotionRouter: emotionRouter,
                    bonjourServer: bonjourServer
                )
            case .avatar:
                AvatarEditorView(bonjourServer: bonjourServer)
            case .sensor:
                SensorView(sensorRouter: sensorRouter, bonjourServer: bonjourServer)
            case .skill:
                SkillView(gateway: gateway)
            case .settings:
                SettingsView(
                    viewModel: SettingsViewModel(gateway: gateway),
                    gateway: gateway
                )
            }
        }
        .background(Theme.backgroundPrimary)
    }
}
