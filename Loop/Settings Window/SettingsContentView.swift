//
//  SettingsContentView.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-18.
//

import Luminare
import SwiftUI

struct SettingsContentView: View {
    @ObservedObject var model: SettingsWindowManager

    @Environment(\.luminareTitleBarHeight) private var titleBarHeight

    var body: some View {
        LuminareDividedStack {
            LuminareSidebar {
                LuminareSidebarSection("Settings", selection: $model.currentTab, items: SettingsTab.allTabs)
            }
            .frame(width: 230)
            .padding(.top, titleBarHeight)
            .luminareBackground()

            LuminarePane {
                model.currentTab.view()
            } header: {
                HStack {
                    Text(model.currentTab.title)
                        .font(.title2)

                    Spacer()
                }
            }
            .frame(width: 390)
        }
        .ignoresSafeArea()
        .environmentObject(model)
    }
}
