import Foundation

public enum InstalledBundleVersion {
    public static func read(atPath path: String) -> String? {
        Bundle(path: path)?.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
