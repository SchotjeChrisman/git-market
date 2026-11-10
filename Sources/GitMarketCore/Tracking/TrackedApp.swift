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
    public var installedPublishedAt: Date?
    /// Read from the installed bundle; only used when no install by Git Market recorded which build is present.
    public var installedBundleVersion: String?

    public var latestKnownTag: String?
    public var latestKnownAssetName: String?
    public var latestKnownPublishedAt: Date?
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

    /// Rolling tags such as "edge" keep their name; the asset name and the publish date carry the build.
    public var hasNewBuildUnderSameTag: Bool {
        if let installedAssetName, let latestKnownAssetName, installedAssetName != latestKnownAssetName { return true }
        if let installedPublishedAt, let latestKnownPublishedAt, latestKnownPublishedAt > installedPublishedAt { return true }
        return installedBuildIsUnknownAndDiffersFromLatest
    }

    /// Installed outside Git Market (or before it recorded builds): the bundle's own version must show up in the latest tag or file name.
    private var installedBuildIsUnknownAndDiffersFromLatest: Bool {
        guard installedAssetName == nil, installedPublishedAt == nil,
              let installedBundleVersion, let latestKnownTag, let latestKnownAssetName else { return false }
        return !latestKnownTag.contains(installedBundleVersion) && !latestKnownAssetName.contains(installedBundleVersion)
    }

    public var hasUpdate: Bool {
        guard let installedTag, let latestKnownTag else { return false }
        if latestKnownTag == installedTag { return hasNewBuildUnderSameTag }
        return VersionComparer.isNewer(latestKnownTag, than: installedTag)
    }
}
