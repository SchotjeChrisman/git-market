import XCTest
@testable import GitMarketCore

final class AppIdentityTests: XCTestCase {
    func testBundleIdentifierIsReverseDomain() {
        XCTAssertTrue(AppIdentity.bundleIdentifier.contains("."))
    }
}
