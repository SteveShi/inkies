import SwiftUI

struct WhatsNewItem: Identifiable, Sendable {
    let id = UUID()
    let version: String
    let title: String
    let features: [Feature]

    struct Feature: Identifiable, Sendable {
        let id = UUID()
        let imageSystemName: String
        let title: String
        let subtitle: String
    }
}

struct WhatsNewSheetView: View {
    let items: [WhatsNewItem]
    @Environment(\.dismiss) private var dismiss

    init(items: [WhatsNewItem] = WhatsNewSheetView.defaultItems) {
        self.items = items
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    if let latest = items.first {
                        headerView(for: latest)
                        featuresView(for: latest.features)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 36)
                .padding(.bottom, 24)
            }

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "Continue")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
            .background(.bar)
        }
        .frame(width: 480, height: 520)
    }

    @ViewBuilder
    private func headerView(for item: WhatsNewItem) -> some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey(item.title))
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
            
            Text(item.version)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func featuresView(for features: [WhatsNewItem.Feature]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: feature.imageSystemName)
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(feature.title))
                            .font(.headline)

                        Text(LocalizedStringKey(feature.subtitle))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    static let defaultItems: [WhatsNewItem] = [
        WhatsNewItem(
            version: "1.1.3",
            title: "What's New in Inkies",
            features: [
                .init(
                    imageSystemName: "bolt.horizontal.fill",
                    title: "Compiler & Preview Resilience",
                    subtitle: "Fixed preview resetting when typing incomplete syntax or cross-file references."
                )
            ]
        ),
        WhatsNewItem(
            version: "1.1.2",
            title: "What's New in Inkies",
            features: [
                .init(
                    imageSystemName: "globe",
                    title: "Native WhatsNew Sheet",
                    subtitle: "Fully localized native SwiftUI release notes view."
                ),
                .init(
                    imageSystemName: "bolt.fill",
                    title: "Codebase Optimization",
                    subtitle: "Cleaned up debug log overhead, redundant memory allocations, and inactive options."
                )
            ]
        ),
        WhatsNewItem(
            version: "1.0.0",
            title: "Inkies 1.0",
            features: [
                .init(
                    imageSystemName: "arrow.clockwise.circle",
                    title: "Sparkle Updates",
                    subtitle: "Stay up to date with the latest features and fixes automatically."
                ),
                .init(
                    imageSystemName: "star.fill",
                    title: "Stable Release",
                    subtitle: "Inkies is now officially 1.0! Thank you for your support."
                )
            ]
        ),
        WhatsNewItem(
            version: "0.7.3",
            title: "What's New in Inkies",
            features: [
                .init(
                    imageSystemName: "sidebar.left",
                    title: "Refined 3-Column Layout",
                    subtitle: "A beautiful native macOS layout with side-by-side editor, preview, and sidebar."
                ),
                .init(
                    imageSystemName: "arrow.uturn.backward",
                    title: "Fixed Undo Logic",
                    subtitle: "The Undo button now correctly reverts your choices while preserving the story log."
                ),
                .init(
                    imageSystemName: "menubar.rectangle",
                    title: "Native Separators",
                    subtitle: "Fixed missing titlebar separators and improved overall window visual hierarchy."
                )
            ]
        )
    ]
}

#Preview {
    WhatsNewSheetView()
}
