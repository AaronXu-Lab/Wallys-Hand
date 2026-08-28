//
//  LoopSupportPaths.swift
//  Loop
//
//  Created by Kai Azim on 2026-02-23.
//

import Foundation

enum LoopSupportPaths {
    /// Returns `~/Library/Application Support` for the supplied home directory.
    static func appSupportDirectory(homeDirectory: URL) -> URL {
        canonical(homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true))
    }

    /// Returns Loop Just's application support root under the supplied home directory.
    static func loopJustDirectory(homeDirectory: URL) -> URL {
        canonical(appSupportDirectory(homeDirectory: homeDirectory).appendingPathComponent("Loop Just", isDirectory: true))
    }

    /// Returns the Loop Just backups directory under the supplied home directory.
    static func backupsDirectory(homeDirectory: URL) -> URL {
        canonical(loopJustDirectory(homeDirectory: homeDirectory).appendingPathComponent("Backups", isDirectory: true))
    }

    /// Returns the Loop Just staging directory under the supplied home directory.
    static func stagingDirectory(homeDirectory: URL) -> URL {
        canonical(loopJustDirectory(homeDirectory: homeDirectory).appendingPathComponent("Staging", isDirectory: true))
    }

    /// Returns the Loop Just rollback directory under the supplied home directory.
    static func rollbackDirectory(homeDirectory: URL) -> URL {
        canonical(loopJustDirectory(homeDirectory: homeDirectory).appendingPathComponent("Rollback.noindex", isDirectory: true))
    }

    /// Resolves symlinks and normalizes the URL to a standardized file URL.
    static func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
