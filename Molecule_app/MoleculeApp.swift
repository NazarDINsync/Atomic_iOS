import SwiftUI

@main
struct MoleculeApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                if showSplash {
                    SplashView()
                        .zIndex(1)
                }
            }
            .tint(Color("AccentColor"))
            .task {
                try? await Task.sleep(for: .seconds(2))
                showSplash = false
            }
        }
    }
}

#Preview {
    RootTabView()
}
