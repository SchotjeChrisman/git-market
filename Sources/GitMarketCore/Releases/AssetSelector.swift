import Foundation

public enum Architecture: Equatable {
    case arm64
    case intel

    public static var current: Architecture {
        #if arch(arm64)
        return .arm64
        #else
        return .intel
        #endif
    }
}

public enum AssetSelectorError: Error, Equatable {
    case invalidNamePattern(String)
}

/// Picks the release file to install for this Mac.
public struct AssetSelector {
    private static let installableExtensions = ["dmg", "zip", "pkg"]
    private static let otherPlatformTokens: Set<String> = [
        "windows", "win", "win32", "win64", "linux", "android", "freebsd", "source", "src",
    ]
    private static let armMarkers = ["arm64", "aarch64", "apple-silicon", "applesilicon"]
    private static let intelMarkers = ["x86_64", "x86-64", "x64", "amd64", "intel"]
    private static let universalMarkers = ["universal"]
    private static let macMarkers = ["mac", "darwin", "osx"]
    private static let extensionBonus = ["dmg": 2, "zip": 1, "pkg": 0]
    private static let ownArchitectureBonus = 4
    private static let universalBonus = 3
    private static let noArchitectureBonus = 2
    private static let macMarkerBonus = 1

    private let architecture: Architecture
    private let namePattern: NSRegularExpression?

    public init(architecture: Architecture = .current, namePattern: String? = nil) throws {
        self.architecture = architecture
        guard let namePattern, !namePattern.isEmpty else {
            self.namePattern = nil
            return
        }
        do {
            self.namePattern = try NSRegularExpression(pattern: namePattern)
        } catch {
            throw AssetSelectorError.invalidNamePattern(namePattern)
        }
    }

    public func select(from assets: [Asset]) -> Asset? {
        let installable = assets.filter { Self.installableExtensions.contains(Self.fileExtension(of: $0.name)) }
        if let namePattern {
            return installable.first { asset in
                namePattern.firstMatch(in: asset.name, range: NSRange(asset.name.startIndex..., in: asset.name)) != nil
            }
        }
        let scored = installable.compactMap { asset in score(asset).map { (asset, $0) } }
        return scored.max { $0.1 < $1.1 }?.0
    }

    /// Nil means the file is for another platform or architecture.
    private func score(_ asset: Asset) -> Int? {
        let name = asset.name.lowercased()
        let tokens = Set(name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        guard tokens.isDisjoint(with: Self.otherPlatformTokens) else { return nil }

        let isArm = Self.armMarkers.contains { name.contains($0) }
        let isIntel = Self.intelMarkers.contains { name.contains($0) }
        let isUniversal = Self.universalMarkers.contains { name.contains($0) }

        var total = Self.extensionBonus[Self.fileExtension(of: name)] ?? 0
        if Self.macMarkers.contains(where: { name.contains($0) }) { total += Self.macMarkerBonus }

        if isUniversal {
            total += Self.universalBonus
        } else if isArm || isIntel {
            let matchesThisMac = (architecture == .arm64 && isArm) || (architecture == .intel && isIntel)
            guard matchesThisMac else { return nil }
            total += Self.ownArchitectureBonus
        } else {
            total += Self.noArchitectureBonus
        }
        return total
    }

    private static func fileExtension(of name: String) -> String {
        (name as NSString).pathExtension.lowercased()
    }
}
