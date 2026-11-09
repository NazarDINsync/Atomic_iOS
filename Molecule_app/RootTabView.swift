import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            SubstanceSearchView()
                .tabItem { Image(systemName: "atom").accessibilityLabel("Substance") }
            ReactionView()
                .tabItem { Image(systemName: "arrow.triangle.merge").accessibilityLabel("Reaction") }
            MixtureView()
                .tabItem { Image(systemName: "flask").accessibilityLabel("Mixture") }
            ChatView()
                .tabItem { Image(systemName: "sparkles").accessibilityLabel("Assistant") }
            SettingsView()
                .tabItem { Image(systemName: "gearshape").accessibilityLabel("Settings") }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
