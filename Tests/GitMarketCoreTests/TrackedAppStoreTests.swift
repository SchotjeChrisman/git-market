import XCTest
@testable import GitMarketCore

final class TrackedAppStoreTests: XCTestCase {
    private func makeStore() throws -> TrackedAppStore {
        TrackedAppStore(fileURL: try makeTemporaryDirectory().appendingPathComponent("nested/apps.json"))
    }

    func testMissingFileLoadsAsEmptyList() throws {
        XCTAssertEqual(try makeStore().load(), [])
    }

    func testSavedAppsComeBackUnchanged() throws {
        let store = try makeStore()
        var app = TrackedApp(
            location: try ForgeLocation(parsing: "github.com/rxhanson/Rectangle"),
            displayName: "Rectangle"
        )
        app.installedTag = "v2.0.3"
        app.installedSignature = .team("ABCDE12345")
        try store.save([app])
        XCTAssertEqual(try store.load(), [app])
    }

    func testCorruptFileThrowsInsteadOfLosingTheList() throws {
        let directory = try makeTemporaryDirectory()
        let file = directory.appendingPathComponent("apps.json")
        try Data("not json".utf8).write(to: file)
        XCTAssertThrowsError(try TrackedAppStore(fileURL: file).load())
    }

    func testHasUpdateComparesLatestKnownTagWithInstalledTag() throws {
        var app = TrackedApp(location: try ForgeLocation(parsing: "github.com/a/b"), displayName: "B")
        XCTAssertFalse(app.hasUpdate)
        app.installedTag = "v1.0.0"
        app.latestKnownTag = "v1.1.0"
        XCTAssertTrue(app.hasUpdate)
        app.installedTag = "v1.1.0"
        XCTAssertFalse(app.hasUpdate)
    }
}
