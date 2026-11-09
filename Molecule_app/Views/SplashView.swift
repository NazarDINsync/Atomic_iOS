import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 32) {
                AtomMark(size: 112)
                    .padding(44)
                    .glassCard(in: Circle())

                VStack(spacing: 6) {
                    Text("Molecule")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    Text("Chemistry, from open data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .offset(y: -20)

            ProgressView()
                .controlSize(.small)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 56)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Molecule is loading")
    }
}

#Preview {
    SplashView()
}
