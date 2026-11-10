import Foundation

public struct TrackedApp: Equatable, Codable, Identifiable {
    public let id: UUID
    public var location: ForgeLocation
    public var displayName: String
    public var includePrereleases: Bool
    public var assetNamePattern: String?

    public var installedTag: String?
    public var installedBundlePath: String?
    public var installedSignature: SignatureInfo?

    public var latestKnownTag: String?
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

    public var hasUpdate: Bool {
        guard let installedTag, let latestKnownTag else { return false }
        return VersionComparer.isNewer(latestKnownTag, than: installedTag)
    }
}
