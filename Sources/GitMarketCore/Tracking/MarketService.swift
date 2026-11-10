import Foundation

public enum MarketError: Error, Equatable {
    case noReleases
    case noInstallableAsset(tag: String)
    case unsupportedPackage(fileName: String)
}

public struct ReleasePreview: Equatable {
    public let location: ForgeLocation
    public let release: Release
    public let asset: Asset
}

/// Looks up, checks and installs apps. Every outside effect is injected through the edge types.
public struct MarketService {
    private let fetcher: ReleaseFetcher
    private let downloader: AssetDownloader
    private let installer: Installer
    private let tokenForHost: (String) throws -> String?
    private let now: () -> Date
    private let architecture: Architecture

    public init(
        fetcher: ReleaseFetcher = ReleaseFetcher(),
        downloader: AssetDownloader = .live,
        installer: Installer,
        tokenForHost: @escaping (String) throws -> String? = { try KeychainTokenStore().token(for: $0) },
        now: @escaping () -> Date = Date.init,
        architecture: Architecture = .current
    ) {
        self.fetcher = fetcher
        self.downloader = downloader
        self.installer = installer
        self.tokenForHost = tokenForHost
        self.now = now
        self.architecture = architecture
    }

    /// Resolves the forge for a repository URL. `kind` is only needed for self-hosted hosts that cannot be detected.
    public func locate(repositoryText: String, kind: ForgeKind? = nil) async throws -> ForgeLocation {
        let location = try ForgeLocation(parsing: repositoryText)
        if let kind { return location.with(kind: kind) }
        if location.kind != nil { return location }
        guard let detected = await fetcher.detectKind(of: location) else {
            throw ForgeError.unknownForge(host: location.host)
        }
        return location.with(kind: detected)
    }

    /// What adding this repository would install.
    public func preview(repositoryText: String, kind: ForgeKind? = nil, includePrereleases: Bool = false) async throws -> ReleasePreview {
        let location = try await locate(repositoryText: repositoryText, kind: kind)
        let release = try await latestRelease(of: location, includePrereleases: includePrereleases)
        let asset = try selectAsset(from: release, namePattern: nil)
        return ReleasePreview(location: location, release: release, asset: asset)
    }

    public func check(_ app: TrackedApp) async throws -> TrackedApp {
        var checked = app
        do {
            checked.latestKnownTag = try await latestRelease(of: app.location, includePrereleases: app.includePrereleases).tag
        } catch MarketError.noReleases {
            // A repository may be tracked before its first release exists.
            checked.latestKnownTag = nil
        }
        checked.lastCheckedAt = now()
        return checked
    }

    public func install(_ app: TrackedApp, allowSigningTeamChange: Bool = false) async throws -> TrackedApp {
        let release = try await latestRelease(of: app.location, includePrereleases: app.includePrereleases)
        let asset = try selectAsset(from: release, namePattern: app.assetNamePattern)
        guard let packageKind = PackageKind(fileName: asset.name) else {
            throw MarketError.unsupportedPackage(fileName: asset.name)
        }

        let packageURL = try await downloader.download(asset)
        // Best effort: the download folder is ours alone and the install result matters more.
        defer { try? FileManager.default.removeItem(at: packageURL.deletingLastPathComponent()) }
        let outcome = try await installer.install(
            InstallRequest(packageURL: packageURL, kind: packageKind, allowSigningTeamChange: allowSigningTeamChange)
        )

        var installed = app
        installed.installedTag = release.tag
        installed.latestKnownTag = release.tag
        installed.installedBundlePath = outcome.bundleURL?.path ?? app.installedBundlePath
        installed.installedSignature = outcome.signature ?? app.installedSignature
        installed.lastCheckedAt = now()
        return installed
    }

    private func latestRelease(of location: ForgeLocation, includePrereleases: Bool) async throws -> Release {
        let releases = try await fetcher.fetchReleases(from: location, token: tokenForHost(location.host))
        guard let release = LatestRelease.find(in: releases, includePrereleases: includePrereleases) else {
            throw MarketError.noReleases
        }
        return release
    }

    private func selectAsset(from release: Release, namePattern: String?) throws -> Asset {
        let selector = try AssetSelector(architecture: architecture, namePattern: namePattern)
        guard let asset = selector.select(from: release.assets) else {
            throw MarketError.noInstallableAsset(tag: release.tag)
        }
        return asset
    }
}
