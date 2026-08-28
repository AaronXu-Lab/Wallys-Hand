//
//  AboutConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-26.
//

import Combine
import Defaults
import Luminare
import SwiftUI

@MainActor
final class AboutConfigurationModel: ObservableObject {
    @Published var didCompleteCopyToClipboard: Bool = false

    let credits: [CreditItem] = [
        .init(
            "Kai",
            Text("Development", comment: "Role title shown in Loop Just’s credits section."),
            url: .init(string: "https://github.com/mrkai77")!,
            avatar: Image(.kai)
        ),
        .init(
            "Kami",
            Text("Development", comment: "Role title shown in Loop Just’s credits section."),
            url: .init(string: "https://github.com/senpaihunters")!,
            avatar: Image(.kami)
        ),
        .init(
            "Jace",
            Text("Design", comment: "Role title shown in Loop Just’s credits section."),
            url: .init(string: "https://x.com/jacethings")!,
            avatar: Image(.jace)
        ),
        .init(
            .init(localized: "Contributors on GitHub"),
            Text("Some features, ideas, and bug fixes", comment: "Role title for contributors on GitHub shown in Loop Just’s credits section."),
            url: .init(string: "https://github.com/MrKai77/Loop-Just/graphs/contributors")!,
            avatar: Image(.github)
        )
    ]

    func copyVersionToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(
            "Version \(VersionDisplay.current.fullDisplay)",
            forType: NSPasteboard.PasteboardType.string
        )

        didCompleteCopyToClipboard = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            didCompleteCopyToClipboard = false
        }
    }
}

struct CreditItem: Identifiable, Equatable {
    var id: String { name }

    let name: String
    let description: Text?
    let url: URL
    let avatar: Image

    init(_ name: String, _ description: Text? = nil, url: URL, avatar: Image) {
        self.name = name
        self.description = description
        self.avatar = avatar
        self.url = url
    }
}

struct AboutConfigurationView: View {
    @Environment(\.openURL) private var openURL

    @StateObject private var model = AboutConfigurationModel()
    @ObservedObject private var updater = Updater.shared

    @Default(.includeDevelopmentVersions) private var includeDevelopmentVersions

    private var updateButtonText: String {
        updater.updatesEnabled ? updater.updateState.text : String(localized: "Updates are disabled")
    }

    var body: some View {
        LuminareForm {
            iconHeader
            updateSection
            communitySection
            creditsSection
        }
    }

    private var iconHeader: some View {
        LuminareSection {
            HStack {
                if let image = NSApp.applicationIconImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 60)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Bundle.main.appName)
                        .fontWeight(.medium)

                    Text("Version \(Text(VersionDisplay.current.fullDisplay))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.copyVersionToClipboard()
                } label: {
                    Image(systemName: "document.on.clipboard")
                        .padding(4)
                        .contentShape(.rect)
                }
                .luminareContentSize(
                    aspectRatio: 1.0,
                    contentMode: .fit,
                    hasFixedHeight: true
                )
                .luminareRoundingBehavior(top: true, bottom: true)
                .luminareSurfaceStyle(.flat)
                .luminarePopover(
                    isPresented: $model.didCompleteCopyToClipboard,
                    arrowEdge: .bottom,
                    shouldHideAnchor: true
                ) {
                    Text("Copied!")
                        .padding(6)
                }
            }
            .padding(.trailing, 8)
            .padding(4)
        }
    }

    private var updateSection: some View {
        LuminareSection {
            LuminareButtonRow {
                Button {
                    Task {
                        await updater.fetchLatestInfo(bypassUpdatesEnabled: true)

                        switch updater.updateState {
                        case .available:
                            await updater.showUpdateWindowIfEligible()
                        case .unavailable, .osNotSupported:
                            break
                        }
                    }
                } label: {
                    Text(.init(updateButtonText))
                }
                .disabled(!updater.updatesEnabled)
            }
            .luminareRoundingBehavior(top: true)

            LuminareToggle("Include development versions", isOn: $includeDevelopmentVersions)
        }
    }

    private var communitySection: some View {
        LuminareSection {
            LuminareButtonRow {
                Button("Send Feedback") {
                    openURL(URL(string: "https://github.com/MrKai77/Loop-Just")!)
                }
            }
            .luminareRoundingBehavior(top: true, bottom: true)
        }
    }

    private var creditsSection: some View {
        LuminareSection(String(localized: "Credits", comment: "Section header shown in settings")) {
            ForEach(model.credits) { credit in
                creditView(credit)
                    .luminareRoundingBehavior(
                        top: (credit == model.credits.first) == true,
                        bottom: (credit == model.credits.last) == true
                    )
            }
        }
    }

    private func creditView(_ credit: CreditItem) -> some View {
        HStack(spacing: 12) {
            credit.avatar
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 40)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
                .clipShape(.circle)

            VStack(alignment: .leading) {
                Text(credit.name)

                if let description = credit.description {
                    description
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                openURL(credit.url)
            } label: {
                Image(systemName: "link")
                    .padding(4)
                    .contentShape(.rect)
            }
            .luminareContentSize(
                aspectRatio: 1.0,
                contentMode: .fit,
                hasFixedHeight: true
            )
            .luminareRoundingBehavior(top: true, bottom: true)
            .luminareSurfaceStyle(.flat)
        }
        .padding(12)
    }
}
