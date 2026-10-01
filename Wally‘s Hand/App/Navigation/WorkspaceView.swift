import AaronUI
import SwiftUI

/// A tool workspace: global navigation stays stable while each tool owns its subnavigation.
struct WorkspaceView: View {
    @ObservedObject var model: WorkspaceWindowManager
    @ObservedObject private var updater = Updater.shared
    private let titleBarHeight: CGFloat = 40
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AUISpacing.lg) {
                Text(Bundle.main.appName)
                    .auiText(.headlineSm)
                    .padding(.horizontal, AUISpacing.xxl)
                    .padding(.top, AUISpacing.lg)
                ScrollView {
                    VStack(alignment: .leading, spacing: AUISpacing.xxl) {
                        sidebarSection("工具", destinations: AppDestination.tools)
                        sidebarSection("应用", destinations: AppDestination.application)
                    }
                    .padding(.horizontal, AUISpacing.lg)
                }
            }
            .frame(width: 220)
            .padding(.top, titleBarHeight)
            .background(.regularMaterial)

            Divider()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: AUISpacing.xs) {
                    Text(model.destination.title)
                        .auiText(.headlineLg)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.destination.subtitle)
                        .auiText(.bodySm)
                        .foregroundStyle(SettingsAppearance.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AUISpacing.xxl)
                .padding(.vertical, AUISpacing.lg)
                .frame(minHeight: 80)
                .background(SettingsAppearance.surface)

                Divider()
                destinationContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(SettingsAppearance.canvas)
            .frame(width: 580)
        }
        .ignoresSafeArea()
        .environmentObject(model)
        .foregroundStyle(SettingsAppearance.ink)
        .buttonStyle(AUIButtonStyle(variant: .outline, size: .sm))
        .tint(AUIColor.accent)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }

    }

    private func sidebarSection(_ title: LocalizedStringKey, destinations: [AppDestination]) -> some View {
        VStack(alignment: .leading, spacing: AUISpacing.xs) {
            Text(title).auiText(.caption).foregroundStyle(AUIColor.onSurfaceMuted)
                .padding(.horizontal, AUISpacing.md)
            ForEach(destinations) { destination in
                Button { model.destination = destination } label: {
                    HStack(spacing: AUISpacing.md) {
                        Image(systemName: destination.symbol).frame(width: 20)
                        Text(destination.title).lineLimit(1)
                        Spacer(minLength: 0)
                        if destination == .about, updater.updateState == .available {
                            Image(systemName: "arrow.down.circle.fill")
                                .accessibilityLabel("有可用更新")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(AUIButtonStyle(variant: model.destination == destination ? .light : .ghost,
                                           size: .md, contentType: .iconText))
                .accessibilityAddTraits(model.destination == destination ? .isSelected : [])
                .help(destination.title)
            }
        }
    }

    @ViewBuilder private var destinationContent: some View {
        switch model.destination {
        case .windows: WindowManagementView(selection: $model.windowTab)
        case .ports: PortConfigurationView()
        case .settings: GeneralConfigurationView()
        case .about: AboutConfigurationView()
        }
    }
}
