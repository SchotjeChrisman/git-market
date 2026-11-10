import Foundation

func loadFixture(_ name: String) throws -> Data {
    let url = try XCTUnwrapURL(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private func XCTUnwrapURL(_ url: URL?) throws -> URL {
    guard let url else { throw CocoaError(.fileNoSuchFile) }
    return url
}
