import AaronUI
import SwiftUI

/// Keep only the dimensions useful for adjusting this temporary page.
enum TempPortLayout {
    static let contentWidth: CGFloat = 580
    static let sidebarWidth: CGFloat = 220
    static let previewWidth: CGFloat = sidebarWidth + contentWidth
    static let previewHeight: CGFloat = 990
    static let pageInset: CGFloat = 20
}

struct TempPortService: Identifiable {
    var id: String { name }
    let name: String
    let port: String

    static let examples: [Self] = [
        .init(name: "gallery", port: "5680"),
        .init(name: "bff", port: "3000"),
        .init(name: "landing", port: "5173"),
        .init(name: "app-design-mock", port: "5678"),
        .init(name: "app-fe-poc", port: "5679"),
        .init(name: "manager-fe-pc", port: "5681"),
        .init(name: "Worker DM", port: "6678"),
        .init(name: "Worker FE", port: "6679"),
        // The ninth card is cropped in the reference; this is placeholder data.
        .init(name: "示例服务", port: "6680")
    ]
}

/// A standalone layout sandbox. All actions are placeholders.
struct TempPortManagementView: View {
    @State private var selection: String? = "端口管理"
    @State private var showingBackupMenu = false

    private var isCanvasPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(TempPortLayout.sidebarWidth)
        } detail: {
            portContent
                .frame(minWidth: TempPortLayout.contentWidth)
                .navigationTitle("端口管理")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("添加服务", systemImage: "plus") {}
                            .buttonStyle(.borderedProminent)
                    }
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                    ToolbarItemGroup(placement: .primaryAction) {
                        backupMenu
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .overlay {
            // Canvas crashes inside NSPopupMenuWindow on this toolchain. Keep its
            // layout interaction in the existing view instead of opening a window.
            if isCanvasPreview && showingBackupMenu {
                ZStack(alignment: .topTrailing) {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { showingBackupMenu = false }
                    VStack(alignment: .leading, spacing: 0) {
                        previewMenuItem("导入配置…")
                        previewMenuItem("导出全部配置…")
                    }
                    .padding(6)
                    .frame(width: 180)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.top, 8)
                    .padding(.trailing, TempPortLayout.pageInset)
                }
            }
        }
    }

    @ViewBuilder private var backupMenu: some View {
        if isCanvasPreview {
            Button {
                showingBackupMenu.toggle()
            } label: {
                Label("服务配置备份", systemImage: "ellipsis")
            }
        } else {
            Menu {
                Button("导入配置…") {}
                Button("导出全部配置…") {}
            } label: {
                Label("服务配置备份", systemImage: "ellipsis")
            }
            .menuIndicator(.hidden)
        }
    }

    private func previewMenuItem(_ title: String) -> some View {
        Button { showingBackupMenu = false } label: {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Wally’s Hand").font(.headline)
                AUIBadge("DEV", size: .sm, variant: .light, color: .blue)
            }
            .padding()

            List(selection: $selection) {
                Section("工具") {
                    Label("窗口管理", systemImage: "rectangle.split.2x2").tag("窗口管理")
                    Label("端口管理", systemImage: "network").tag("端口管理")
                }
                Section("应用") {
                    Label("通用设置", systemImage: "gearshape").tag("通用设置")
                    Label("关于", systemImage: "info.circle").tag("关于")
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var portContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("启动本地服务、保留指定端口，并在服务异常时重启。")
                .foregroundStyle(.secondary)
                .padding(TempPortLayout.pageInset)

            Divider()
                .padding(.horizontal)

            List {
                AUIItemSectionGroup {
                    ForEach(TempPortService.examples) { service in
                        TempPortServiceItem(service: service)
                    }
                }
            }
            .auiItemListStyle()
        }
    }
}

#Preview("Temp · 端口管理布局") {
    TempPortManagementView()
        .frame(width: TempPortLayout.previewWidth, height: TempPortLayout.previewHeight)
}

struct TempPortServiceItem: View {
    let service: TempPortService

    var body: some View {
        AUIItem(service.name,
                description: ":\(service.port) · 未启用",
                trailingType: .buttons) {
            HStack(spacing: 12) {
                AUIButton("启动并保护", size: .sm) {}
                Button("详情", systemImage: "chevron.right") {}
                    .buttonStyle(.bordered)
            }
        }
    }
}
