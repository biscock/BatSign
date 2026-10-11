import Foundation
import SwiftUI
import OSLog

/// Own the incoming bytes before the asynchronous extraction/signing pipeline.
@MainActor
final class ExternalIPAImport: ObservableObject {
	static let shared = ExternalIPAImport()
	@Published private(set) var importingCount = 0
	private var activeURLs: Set<URL> = []

	@discardableResult
	func receive(_ url: URL) -> Bool {
		guard url.isFileURL, ["ipa", "tipa"].contains(url.pathExtension.lowercased()) else { return false }
		guard activeURLs.insert(url).inserted else { return true }
		importingCount += 1
		// False is normal for an already readable Inbox copy; try reading it anyway.
		let scoped = url.startAccessingSecurityScopedResource()
		Task {
			do {
				let staged = try await Task.detached(priority: .userInitiated) {
					defer { if scoped { url.stopAccessingSecurityScopedResource() } }
					return try Self.stage(url)
				}.value
				FR.handlePackageFile(staged, signImmediately: true) { error in
					Task { @MainActor in
						try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
						self.finish(url, error: error)
					}
				}
			} catch {
				finish(url, error: error)
			}
		}
		return true
	}

	private func finish(_ url: URL, error: Error?) {
		activeURLs.remove(url)
		importingCount -= 1
		if let error {
			Logger.misc.error("External IPA import failed: \(error.localizedDescription, privacy: .public)")
			// This queues the alert until a foreground presenter exists, including cold launch.
			AutoSignManager.shared.reportInstallOutcome(
				title: "Import failed",
				message: "\(url.lastPathComponent): \(error.localizedDescription)",
				isFailure: true
			)
		}
	}

	nonisolated private static func stage(_ source: URL) throws -> URL {
		let fm = FileManager.default
		let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		// Launch-time tmp cleanup must never remove an incoming IPA.
		let directory = support.appendingPathComponent("ExternalImports", isDirectory: true)
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try fm.createDirectory(at: directory, withIntermediateDirectories: true)
		let destination = directory.appendingPathComponent("package." + source.pathExtension.lowercased())
		do {
			var coordinationError: NSError?
			var copyError: Error?
			var copied = false
			NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
				do {
					try fm.copyItem(at: readable, to: destination)
					copied = true
				} catch { copyError = error }
			}
			if let coordinationError { throw coordinationError }
			if let copyError { throw copyError }
			guard copied else { throw CocoaError(.fileReadUnknown) }
			return destination
		} catch {
			try? fm.removeItem(at: directory)
			throw error
		}
	}
}
