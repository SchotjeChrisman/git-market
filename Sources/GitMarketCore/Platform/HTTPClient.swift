import Foundation

/// The network edge. Everything above it builds requests and parses bytes, so tests feed it fixtures.
public struct HTTPClient {
    public var send: (URLRequest) async throws -> (Data, HTTPURLResponse)

    public init(send: @escaping (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.send = send
    }

    public static let live = HTTPClient { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ForgeError.malformedResponse
        }
        return (data, httpResponse)
    }
}
