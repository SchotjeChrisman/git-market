import XCTest
@testable import GitMarketCore

final class AssetSelectorTests: XCTestCase {
    private func assets(_ names: [String]) -> [Asset] {
        names.map { Asset(name: $0, size: nil, downloadURL: URL(string: "https://example.com/\($0)")!) }
    }

    private func pick(_ names: [String], architecture: Architecture, pattern: String? = nil) throws -> String? {
        try AssetSelector(architecture: architecture, namePattern: pattern).select(from: assets(names))?.name
    }

    func testPrefersDmgOverZipAndPkg() throws {
        let names = ["Rectangle2.0.4.zip", "Rectangle2.0.4.pkg", "Rectangle2.0.4.dmg", "Rectangle111-105.delta"]
        XCTAssertEqual(try pick(names, architecture: .arm64), "Rectangle2.0.4.dmg")
    }

    func testPicksOwnArchitecture() throws {
        let names = ["App-1.0-arm64.dmg", "App-1.0-x64.dmg"]
        XCTAssertEqual(try pick(names, architecture: .arm64), "App-1.0-arm64.dmg")
        XCTAssertEqual(try pick(names, architecture: .intel), "App-1.0-x64.dmg")
    }

    func testUniversalBeatsPlainButLosesToOwnArchitecture() throws {
        XCTAssertEqual(try pick(["App.dmg", "App-universal.dmg"], architecture: .arm64), "App-universal.dmg")
        XCTAssertEqual(try pick(["App-universal.dmg", "App-arm64.dmg"], architecture: .arm64), "App-arm64.dmg")
    }

    func testOtherPlatformsAreRejectedButDarwinIsNotMistakenForWin() throws {
        let names = ["tool-windows-amd64.zip", "tool-linux-amd64.zip", "tool-darwin-arm64.zip", "tool.exe", "tool.AppImage"]
        XCTAssertEqual(try pick(names, architecture: .arm64), "tool-darwin-arm64.zip")
    }

    func testReturnsNilWhenNothingFitsThisMac() throws {
        XCTAssertNil(try pick(["tool-linux.zip", "tool-darwin-x86_64.zip"], architecture: .arm64))
    }

    func testCustomPatternOverridesScoring() throws {
        let names = ["App-1.0.dmg", "App-1.0-extras.zip"]
        XCTAssertEqual(try pick(names, architecture: .arm64, pattern: "extras"), "App-1.0-extras.zip")
    }

    func testInvalidPatternThrows() {
        XCTAssertThrowsError(try AssetSelector(architecture: .arm64, namePattern: "(")) {
            XCTAssertEqual($0 as? AssetSelectorError, .invalidNamePattern("("))
        }
    }
}
