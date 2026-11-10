import XCTest
@testable import GitMarketCore

final class LatestReleaseTests: XCTestCase {
    private func release(_ tag: String, daysAgo: Int?, prerelease: Bool = false) -> Release {
        let date = daysAgo.map { Date(timeIntervalSince1970: 1_800_000_000 - Double($0) * 86_400) }
        return Release(tag: tag, name: nil, isPrerelease: prerelease, publishedAt: date, pageURL: nil, assets: [])
    }

    func testNewestByDateWinsEvenWhenListedLater() {
        let releases = [release("v1", daysAgo: 10), release("v2", daysAgo: 1)]
        XCTAssertEqual(LatestRelease.find(in: releases, includePrereleases: false)?.tag, "v2")
    }

    func testPrereleasesAreSkippedUnlessAsked() {
        let releases = [release("v2-beta", daysAgo: 1, prerelease: true), release("v1", daysAgo: 10)]
        XCTAssertEqual(LatestRelease.find(in: releases, includePrereleases: false)?.tag, "v1")
        XCTAssertEqual(LatestRelease.find(in: releases, includePrereleases: true)?.tag, "v2-beta")
    }

    func testMissingDatesKeepForgeOrder() {
        let releases = [release("first", daysAgo: nil), release("second", daysAgo: nil)]
        XCTAssertEqual(LatestRelease.find(in: releases, includePrereleases: false)?.tag, "first")
    }

    func testEmptyListHasNoLatest() {
        XCTAssertNil(LatestRelease.find(in: [], includePrereleases: true))
    }
}
