import AppKit

public enum RunningApps {
    private static let quitTimeout: TimeInterval = 5
    private static let pollInterval: UInt64 = 100_000_000

    /// Asks every running copy of the app at `bundleURL` to quit and waits briefly for it.
    public static func terminate(_ bundleURL: URL) async {
        let running = NSWorkspace.shared.runningApplications.filter { $0.bundleURL == bundleURL }
        guard !running.isEmpty else { return }
        running.forEach { $0.terminate() }

        let deadline = Date().addingTimeInterval(quitTimeout)
        while running.contains(where: { !$0.isTerminated }) && Date() < deadline {
            try? await Task.sleep(nanoseconds: pollInterval)
        }
    }
}
