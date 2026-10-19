import SwiftUI

/// Step-by-step guide to the app, reachable from Settings and the home toolbar.
/// Content comes from `AppConfig.howTo`; each app writes its own steps in the order a new user does them.
struct HowToView: View {
    var body: some View {
        List {
            Section {
                Text(AppConfig.howToIntro)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(AppConfig.howTo.enumerated()), id: \.element.id) { index, step in
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 36, height: 36)
                            Text("\(index + 1)").font(.headline).foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Label(step.title, systemImage: step.symbol).font(.headline)
                            Text(step.body).font(.subheadline).foregroundStyle(.secondary)
                            if let tip = step.tip {
                                Text(tip).font(.footnote).foregroundStyle(.secondary).italic()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                Link(destination: URL(string: "mailto:\(AppConfig.supportEmail)")!) {
                    Label("Still stuck? Email support", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("How do I use \(AppConfig.appName)?")
        .navigationBarTitleDisplayMode(.inline)
    }
}
