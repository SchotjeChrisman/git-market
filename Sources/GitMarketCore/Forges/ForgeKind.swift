public enum ForgeKind: String, Codable, CaseIterable {
    case github
    case forgejo
    case gitlab
}

public enum ForgeError: Error, Equatable {
    case invalidRepositoryURL(String)
    case unknownForge(host: String)
    case http(status: Int)
    case malformedResponse
}
