import Foundation

/// One forge's release API: builds the request, parses the answer. No I/O happens here.
public protocol ReleaseSource {
    func releasesRequest(for location: ForgeLocation, token: String?) throws -> URLRequest
    func parseReleases(from data: Data) throws -> [Release]
}

public enum ReleaseSources {
    public static func source(for kind: ForgeKind) -> ReleaseSource {
        switch kind {
        case .github: return GitHubSource()
        case .forgejo: return ForgejoSource()
        case .gitlab: return GitLabSource()
        }
    }
}

enum ReleaseDateParser {
    static func parse(_ text: String?) -> Date? {
        guard let text else { return nil }
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return plain.date(from: text) ?? fractional.date(from: text)
    }
}

func makeRequest(url: String, headers: [String: String]) throws -> URLRequest {
    guard let url = URL(string: url) else { throw ForgeError.invalidRepositoryURL(url) }
    var request = URLRequest(url: url)
    for (field, value) in headers {
        request.setValue(value, forHTTPHeaderField: field)
    }
    return request
}
