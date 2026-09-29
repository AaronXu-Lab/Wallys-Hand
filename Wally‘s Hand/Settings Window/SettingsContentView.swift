//
//  SettingsContentView.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-18.
//

import AaronUI
import Luminare
import SwiftUI

struct SettingsContentView: View {
    @ObservedObject var model: SettingsWindowManager

    @Environment(\.luminareTitleBarHeight) private var titleBarHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LuminareDividedStack {
            LuminareSidebar {
                LuminareSidebarSection("Settings", selection: $model.currentTab, items: SettingsTab.allTabs)
            }
            .frame(width: 200)
            .padding(.top, titleBarHeight)
            .background(.regularMaterial)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.currentTab.title)
                        .auiText(.headlineLg)

                    Text(model.currentTab.subtitle)
                        .auiText(.bodySm)
                        .foregroundStyle(SettingsAppearance.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AUISpacing.xxl)
                .frame(height: 80)
                .background(SettingsAppearance.surface)

                Rectangle().fill(SettingsAppearance.line).frame(height: 1)
                model.currentTab.view()
                    .luminareListFixedHeight(until: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(SettingsAppearance.canvas)
            .frame(width: 580)
        }
        .ignoresSafeArea()
        .environmentObject(model)
        .foregroundStyle(SettingsAppearance.ink)
        .luminareTint(overridingWith: SettingsAppearance.accent)
        .luminareCornerRadius(AUIRadius.lg)
        .luminareAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.19))
        .luminareAnimationFast(.easeInOut(duration: reduceMotion ? 0 : 0.14))
    }
}
