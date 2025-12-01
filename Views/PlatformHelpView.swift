import SwiftUI

struct PlatformHelpView: View {
    private let sections: [(MarketplacePlatform, String)] = [
        (.ebay, "Listing policies, category best practices, and fee transparency."),
        (.mercari, "Preferred shipping options, moderation expectations, and dispute tips."),
        (.facebook, "Marketplace listing quality, response SLAs, and commerce policies.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Platform Help Center")
                    .font(.largeTitle)
                    .bold()
                Text("Quick guidance for each marketplace with links to documentation.")
                    .foregroundColor(.secondary)

                ForEach(sections, id: \.0) { platform, description in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: icon(for: platform))
                                .foregroundColor(.blue)
                            Text(platform.rawValue)
                                .font(.title3)
                                .bold()
                            Spacer()
                            Link("Docs", destination: URL(string: "https://www.google.com/search?q=\(platform.rawValue)+api")!)
                        }
                        Text(description)
                            .foregroundColor(.secondary)
                        Divider()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Help")
    }

    private func icon(for platform: MarketplacePlatform) -> String {
        switch platform {
        case .ebay: return "e.circle.fill"
        case .mercari: return "m.circle.fill"
        case .facebook: return "f.circle.fill"
        }
    }
}
