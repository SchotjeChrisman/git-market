import XCTest
@testable import GitMarketCore

final class ForgeLocationTests: XCTestCase {
    func testGitHubReleaseURLReducesToOwnerAndRepo() throws {
        let location = try ForgeLocation(parsing: "https://github.com/rxhanson/Rectangle/releases/tag/v2.0.4")
        XCTAssertEqual(location.kind, .github)
        XCTAssertEqual(location.projectPath, "rxhanson/Rectangle")
    }

    func testSchemeIsOptionalAndGitSuffixIsStripped() throws {
        let location = try ForgeLocation(parsing: "codeberg.org/forgejo/forgejo.git")
        XCTAssertEqual(location.kind, .forgejo)
        XCTAssertEqual(location.projectPath, "forgejo/forgejo")
    }

    func testGitLabKeepsSubgroupsAndCutsAtDashSegment() throws {
        let location = try ForgeLocation(parsing: "https://gitlab.com/group/sub/project/-/releases")
        XCTAssertEqual(location.kind, .gitlab)
        XCTAssertEqual(location.projectPath, "group/sub/project")
    }

    func testSelfHostedHostHasNoKindUntilResolved() throws {
        let location = try ForgeLocation(parsing: "http://git.home.lan:3000/me/tool")
        XCTAssertNil(location.kind)
        XCTAssertEqual(location.host, "git.home.lan:3000")
        XCTAssertEqual(location.scheme, "http")
        XCTAssertEqual(location.with(kind: .forgejo).projectPath, "me/tool")
    }

    func testURLWithoutRepositoryIsRejected() {
        XCTAssertThrowsError(try ForgeLocation(parsing: "https://github.com/rxhanson"))
    }
}
