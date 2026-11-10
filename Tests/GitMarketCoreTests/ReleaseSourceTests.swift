import XCTest
@testable import GitMarketCore

final class ReleaseSourceTests: XCTestCase {
    func testGitHubRequestUsesPublicAPIAndBearerToken() throws {
        let location = try ForgeLocation(parsing: "github.com/rxhanson/Rectangle")
        let request = try GitHubSource().releasesRequest(for: location, token: "abc")
        XCTAssertEqual(request.url?.absoluteString, "https://api.github.com/repos/rxhanson/Rectangle/releases?per_page=30")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc")
    }

    func testGitHubEnterpriseUsesV3Path() throws {
        let location = try ForgeLocation(parsing: "https://ghe.example.com/team/app").with(kind: .github)
        let request = try GitHubSource().releasesRequest(for: location, token: nil)
        XCTAssertEqual(request.url?.absoluteString, "https://ghe.example.com/api/v3/repos/team/app/releases?per_page=30")
    }

    func testForgejoRequestUsesV1PathAndTokenScheme() throws {
        let location = try ForgeLocation(parsing: "https://codeberg.org/forgejo/forgejo")
        let request = try ForgejoSource().releasesRequest(for: location, token: "abc")
        XCTAssertEqual(request.url?.absoluteString, "https://codeberg.org/api/v1/repos/forgejo/forgejo/releases?limit=30")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "token abc")
    }

    func testGitLabRequestEncodesProjectPath() throws {
        let location = try ForgeLocation(parsing: "https://gitlab.com/group/sub/project")
        let request = try GitLabSource().releasesRequest(for: location, token: "abc")
        XCTAssertEqual(request.url?.absoluteString, "https://gitlab.com/api/v4/projects/group%2Fsub%2Fproject/releases?per_page=30")
        XCTAssertEqual(request.value(forHTTPHeaderField: "PRIVATE-TOKEN"), "abc")
    }

    func testParsesGitHubFixture() throws {
        let releases = try GitHubSource().parseReleases(from: loadFixture("github-releases"))
        let latest = try XCTUnwrap(releases.first)
        XCTAssertEqual(latest.tag, "v2.0.4")
        XCTAssertFalse(latest.isPrerelease)
        XCTAssertNotNil(latest.publishedAt)
        XCTAssertTrue(latest.assets.contains { $0.name == "Rectangle2.0.4.dmg" })
    }

    func testParsesForgejoFixtureWithOffsetDate() throws {
        let releases = try ForgejoSource().parseReleases(from: loadFixture("forgejo-releases"))
        let latest = try XCTUnwrap(releases.first)
        XCTAssertEqual(latest.tag, "v17.0.1")
        XCTAssertNotNil(latest.publishedAt)
        XCTAssertFalse(latest.assets.isEmpty)
    }

    func testParsesGitLabFixtureWithFractionalDate() throws {
        let releases = try GitLabSource().parseReleases(from: loadFixture("gitlab-releases"))
        let latest = try XCTUnwrap(releases.first)
        XCTAssertEqual(latest.tag, "v1.128.0")
        XCTAssertNotNil(latest.publishedAt)
        XCTAssertTrue(latest.assets.allSatisfy { $0.downloadURL.absoluteString.contains("/-/releases/") })
    }

    func testDraftReleasesAreDropped() throws {
        let json = #"[{"tag_name":"v1","name":null,"prerelease":false,"draft":true,"published_at":null,"html_url":null,"assets":[]}]"#
        XCTAssertTrue(try GitHubSource().parseReleases(from: Data(json.utf8)).isEmpty)
    }

    func testGarbageThrowsMalformedResponse() {
        XCTAssertThrowsError(try GitLabSource().parseReleases(from: Data("nope".utf8))) {
            XCTAssertEqual($0 as? ForgeError, .malformedResponse)
        }
    }
}
