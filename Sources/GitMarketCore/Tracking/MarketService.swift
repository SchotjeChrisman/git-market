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

    /// What adding this repository would install. `kind` is only needed for self-hosted hosts that cannot be detected.
    public func preview(repositoryText: String, kind: ForgeKind? = nil) async throws -> ReleasePreview {
        var location = try ForgeLocation(parsing: repositoryText)
        if let kind {
            location = location.with(kind: kind)
        } else if location.kind == nil {
            guard let detected = await fetcher.detectKind(of: location) else {
                throw ForgeError.unknownForge(host: location.host)
            }
            location = location.with(kind: detected)
        }
        let release = try await latestRelease(of: location, includePrereleases: false)
        let asset = try selectAsset(from: release, namePattern: nil)
        return ReleasePreview(location: location, release: release, asset: asset)
    }

    public func check(_ app: TrackedApp) async throws -> TrackedApp {
        let release = try await latestRelease(of: app.location, includePrereleases: app.includePrereleases)
        var checked = app
        checked.latestKnownTag = release.tag
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
