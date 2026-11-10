import XCTest
@testable import GitMarketCore

final class AppBundleLocatorTests: XCTestCase {
    private func makeDirectory(_ path: String, in root: URL) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
    }

    func testFindsAppAtTopLevel() throws {
        let root = try makeTemporaryDirectory()
        try makeDirectory("Tool.app", in: root)
        XCTAssertEqual(try AppBundleLocator.find(in: root).lastPathComponent, "Tool.app")
    }

    func testFindsAppOneFolderDown() throws {
        let root = try makeTemporaryDirectory()
        try makeDirectory("Release/Tool.app", in: root)
        XCTAssertEqual(try AppBundleLocator.find(in: root).lastPathComponent, "Tool.app")
    }

    func testThrowsWhenThereIsNoApp() throws {
        let root = try makeTemporaryDirectory()
        try makeDirectory("docs", in: root)
        XCTAssertThrowsError(try AppBundleLocator.find(in: root)) {
            XCTAssertEqual($0 as? InstallError, .noAppBundleFound)
        }
    }
}
