import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var index = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                ForEach(Array(AppConfig.onboarding.enumerated()), id: \.element.id) { offset, page in
                    VStack(spacing: 20) {
                        Image(systemName: page.symbol)
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                            .padding(.bottom, 8)
                        Text(page.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(page.body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                    .padding(.horizontal, 32)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if index < AppConfig.onboarding.count - 1 {
                    withAnimation { index += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(index < AppConfig.onboarding.count - 1 ? "Continue" : "Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
