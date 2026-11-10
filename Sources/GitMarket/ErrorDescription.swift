import GitMarketCore

/// Plain-language text for the errors a person can act on.
enum ErrorDescription {
    private static let notFoundStatus = 404
    private static let accessDeniedStatuses: Set<Int> = [401, 403, 429]

    static func text(for error: Error) -> String {
        switch error {
        case ForgeError.http(let status) where status == notFoundStatus:
            return "Repository or releases not found (HTTP 404)."
        case ForgeError.http(let status) where accessDeniedStatuses.contains(status):
            return "Access denied or rate limited (HTTP \(status)). Add an access token in Settings."
        case ForgeError.http(let status):
            return "The server answered HTTP \(status)."
        case ForgeError.invalidRepositoryURL:
            return "That does not look like a repository URL."
        case ForgeError.unknownForge(let host):
            return "Cannot tell which forge runs on \(host). Pick one below."
        case ForgeError.malformedResponse:
            return "The server's answer was not a release list."
        case MarketError.noReleases:
            return "No release found. If it only has pre-releases, turn on Include pre-releases; otherwise you can track it and install once one appears."
        case MarketError.noInstallableAsset(let tag):
            return "Release \(tag) has no .dmg, .zip or .pkg for this Mac."
        case MarketError.unsupportedPackage(let fileName):
            return "\(fileName) is not a .dmg, .zip or .pkg."
        case InstallError.noAppBundleFound:
            return "No .app was found inside the download."
        case InstallError.commandFailed(let tool, let status, let message):
            return "\(tool) failed (\(status)): \(message)"
        case AssetSelectorError.invalidNamePattern(let pattern):
            return "Invalid asset pattern: \(pattern)"
        default:
            return error.localizedDescription
        }
    }
}
