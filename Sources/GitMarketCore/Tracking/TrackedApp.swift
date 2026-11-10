import Foundation

public struct TrackedApp: Equatable, Codable, Identifiable {
    public let id: UUID
    public var location: ForgeLocation
    public var displayName: String
    public var includePrereleases: Bool
    public var assetNamePattern: String?

    public var installedTag: String?
    public var installedAssetName: String?
    public var installedBundlePath: String?
    public var installedSignature: SignatureInfo?

    public var latestKnownTag: String?
    public var latestKnownAssetName: String?
    public var lastCheckedAt: Date?

    public init(
        id: UUID = UUID(),
        location: ForgeLocation,
        displayName: String,
        includePrereleases: Bool = false,
        assetNamePattern: String? = nil
    ) {
        self.id = id
        self.location = location
        self.displayName = displayName
        self.includePrereleases = includePrereleases
        self.assetNamePattern = assetNamePattern
    }

    /// Tracked but never installed, and a release is available now.
    public var isInstallable: Bool { installedTag == nil && latestKnownTag != nil }

    /// Rolling tags such as "edge" keep their name; the asset name carries the build.
    public var hasNewBuildUnderSameTag: Bool {
        guard let installedAssetName, let latestKnownAssetName else { return false }
        return installedAssetName != latestKnownAssetName
    }

    public var hasUpdate: Bool {
        guard let installedTag, let latestKnownTag else { return false }
        if latestKnownTag == installedTag { return hasNewBuildUnderSameTag }
        return VersionComparer.isNewer(latestKnownTag, than: installedTag)
    }
}
