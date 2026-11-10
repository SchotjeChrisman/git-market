import Foundation

/// Decides whether a release tag is an update over the installed one.
/// Tags are free-form, so anything without a numeric version only counts as "different".
public enum VersionComparer {
    private static let numericVersion = try! NSRegularExpression(pattern: #"\d+(\.\d+)*"#)

    private struct ParsedVersion {
        let numbers: [Int]
        let isPrerelease: Bool
    }

    public static func isNewer(_ candidateTag: String, than installedTag: String) -> Bool {
        guard candidateTag != installedTag else { return false }
        guard let candidate = parse(candidateTag), let installed = parse(installedTag) else { return true }

        let length = max(candidate.numbers.count, installed.numbers.count)
        for index in 0..<length {
            let candidateNumber = index < candidate.numbers.count ? candidate.numbers[index] : 0
            let installedNumber = index < installed.numbers.count ? installed.numbers[index] : 0
            if candidateNumber != installedNumber { return candidateNumber > installedNumber }
        }
        return installed.isPrerelease && !candidate.isPrerelease
    }

    private static func parse(_ tag: String) -> ParsedVersion? {
        let range = NSRange(tag.startIndex..., in: tag)
        guard
            let match = numericVersion.firstMatch(in: tag, range: range),
            let matchRange = Range(match.range, in: tag)
        else { return nil }
        let numbers = tag[matchRange].split(separator: ".").compactMap { Int($0) }
        return ParsedVersion(numbers: numbers, isPrerelease: isPrereleaseSuffix(tag[matchRange.upperBound...]))
    }

    /// "-beta.1" and "rc2" mark a pre-release; "+build5" is build metadata and does not.
    private static func isPrereleaseSuffix(_ suffix: Substring) -> Bool {
        if suffix.hasPrefix("+") { return false }
        return suffix.hasPrefix("-") || suffix.contains(where: \.isLetter)
    }
}
