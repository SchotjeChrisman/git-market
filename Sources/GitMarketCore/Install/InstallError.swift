public enum InstallError: Error, Equatable {
    case commandFailed(tool: String, status: Int32, message: String)
    case noAppBundleFound
    case signingTeamChanged(previous: String, new: SignatureInfo)
}
