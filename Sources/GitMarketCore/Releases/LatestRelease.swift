import Foundation

public enum LatestRelease {
    /// Newest by publish date; forges list newest first, so that order breaks ties and covers missing dates.
    public static func find(in releases: [Release], includePrereleases: Bool) -> Release? {
        let candidates = releases.enumerated().filter { includePrereleases || !$0.element.isPrerelease }
        let newest = candidates.max { left, right in
            let leftDate = left.element.publishedAt ?? .distantPast
            let rightDate = right.element.publishedAt ?? .distantPast
            if leftDate != rightDate { return leftDate < rightDate }
            return left.offset > right.offset
        }
        return newest?.element
    }
}
