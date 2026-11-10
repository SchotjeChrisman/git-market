import XCTest
@testable import GitMarketCore

final class VersionComparerTests: XCTestCase {
    func testNumericOrderingIgnoresLeadingV() {
        XCTAssertTrue(VersionComparer.isNewer("v1.10.0", than: "v1.9.9"))
        XCTAssertFalse(VersionComparer.isNewer("v1.9.9", than: "v1.10.0"))
    }

    func testMissingTrailingPartsCountAsZero() {
        XCTAssertFalse(VersionComparer.isNewer("1.2", than: "1.2.0"))
        XCTAssertTrue(VersionComparer.isNewer("1.2.1", than: "1.2"))
    }

    func testSameTagIsNotNewer() {
        XCTAssertFalse(VersionComparer.isNewer("v2.0.4", than: "v2.0.4"))
    }

    func testFinalReleaseBeatsItsOwnPrerelease() {
        XCTAssertTrue(VersionComparer.isNewer("1.0.0", than: "1.0.0-beta.2"))
        XCTAssertFalse(VersionComparer.isNewer("1.0.0-beta.2", than: "1.0.0"))
    }

    func testBuildMetadataIsNotAPrerelease() {
        XCTAssertFalse(VersionComparer.isNewer("1.0.0", than: "1.0.0+build5"))
    }

    func testTagsWithoutNumbersCountAsUpdatesWhenDifferent() {
        XCTAssertTrue(VersionComparer.isNewer("nightly-latest", than: "stable"))
        XCTAssertTrue(VersionComparer.isNewer("2.0.0", than: "stable"))
    }
}
