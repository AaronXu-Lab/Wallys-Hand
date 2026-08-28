//
//  Updater.swift
//  Loop
//
//  Created by Kami on 11/5/2024.
//

import Defaults
import Luminare
import Scribe
import SwiftUI

@Loggable
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    @Published private(set) var updateState: UpdateAvailability = .unavailable

    @Published private(set) var installState: InstallState = .ready
    @Published private(set) var progressBar: Double = 0
    var updatesEnabled: Bool { Self.checkIfUpdatesEnabled() }
    @Published private(set) var changelog: [ChangelogSection] = []
    @Published var expandedChangelogSections: Set<String> = [] // By ID
    @Published private(set) var updateManifest: UpdateManifest?

    private var windowController: NSWindowController?
    private var includeDevelopmentVersions: Bool { Defaults[.includeDevelopmentVersions] }

    private var updateFetcherTask: Task<(), Never>?

    private let updateChecker: UpdateChecker
    private let downloader: UpdateDownloader
    private let installer: UpdateInstaller

    private init() {
        // Initialize new updater system components
        self.updateChecker = UpdateChecker()
        self.downloader = UpdateDownloader()
        self.installer = UpdateInstaller()

    }

    private static func checkIfUpdatesEnabled() -> Bool {
        return Defaults[.updatesEnabled]
    }

    func dismissWindow() {
        windowController?.close()
        windowController = nil

        // Clear update state when window is dismissed
        updateManifest = nil
        progressBar = 0
        installState = .ready
    }

    /// Pulls the latest release information from GitHub and updates the app state accordingly.
    func fetchLatestInfo(bypassUpdatesEnabled: Bool = false) async {
        // Don't run update checks while actively downloading
        if downloader.isDownloading == true {
            return
        }

        if let updateFetcherTask {
            await updateFetcherTask.value // If already fetching, wait for it to finish
            return
        }

        updateFetcherTask = Task {
            defer { updateFetcherTask = nil }

            // Don't clear update state if window is currently showing (user is interacting)
            if windowController?.window?.isVisible != true {
                updateManifest = nil
                progressBar = 0
            }

            // Early return if updates are disabled and not forcing
            guard updatesEnabled || bypassUpdatesEnabled else {
                updateState = .unavailable
                log.warn("Updates are disabled. Not fetching latest info.")
                return
            }

            log.info("Fetching latest release info...")

            do {
                // Use GitHub releases API
                let channel: UpdateChannel = includeDevelopmentVersions ? .development : .stable

                let currentVersion = Bundle.main.appVersion?.filter(\.isASCII)
                    .trimmingCharacters(in: .whitespaces) ?? "0.0.1"
                let currentBuild = Bundle.main.appBuild ?? 0

                if let manifest = try await updateChecker.checkForUpdate(
                    currentVersion: currentVersion,
                    currentBuild: currentBuild,
                    channel: channel
                ) {
                    changelog = ChangelogParser.parse(manifest.releaseNotes.body)
                    if let firstSection = changelog.first {
                        expandedChangelogSections = [firstSection.id]
                    }

                    updateManifest = manifest
                    updateState = .available

                    log.notice("Update available: \(manifest.version) build \(manifest.buildNumber)")
                } else {
                    updateState = .unavailable

                    log.info("No updates available")
                }
            } catch {
                if case .incompatibleSystem? = error as? UpdateError {
                    updateState = .osNotSupported
                } else {
                    updateState = .unavailable
                }

                log.error("Error fetching release info: \(error.localizedDescription)")
            }
        }

        await updateFetcherTask?.value
    }

    func showUpdateWindowIfEligible() async {
        guard updateState == .available else { return }

        if windowController?.window == nil {
            windowController = .init(window: LuminareWindow(cornerRadius: 20) { UpdateView() })
        }
        windowController?.window?.makeKeyAndOrderFront(self)
        windowController?.window?.orderFrontRegardless()

        log.ui("Update window shown")
    }

    /// Downloads the update from GitHub and installs it
    func downloadAndInstallUpdate() async throws {
        guard let manifest = updateManifest else {
            let error = UpdateError.installationFailed(
                "No update information is available. Please check for updates again and retry."
            )
            log.error("Cannot start installation: update manifest is missing")
            progressBar = 0
            installState = .failed(error)
            throw error
        }

        installState = .installing

        log.info("Installing update: \(manifest.version)")

        do {
            let downloadedFileURL = try await downloader.downloadUpdate(manifest: manifest) { [weak self] progress in
                self?.progressBar = progress.percentage * 0.75
            }

            try await installer.installUpdate(from: downloadedFileURL, manifest: manifest) { [weak self] progress in
                self?.progressBar = 0.75 + (progress.percentage * 0.25)
            }

            progressBar = 1.0
            updateState = .unavailable

            // Brief delay before showing restart button
            try? await Task.sleep(for: .seconds(1))

            installState = .readyToRestart

            log.success("Update installed successfully")
        } catch {
            log.error("Update installation failed: \(error)")
            progressBar = 0
            installState = .failed(error)
            throw error
        }
    }

    func relaunchAfterUpdate() async {
        guard installState == .readyToRestart else {
            log.error("Cannot restart as the install state is \(installState)")
            return
        }

        await installer.restartApplication()
    }
}
