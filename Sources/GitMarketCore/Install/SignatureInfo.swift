import Foundation

public enum SignatureInfo: Equatable, Codable {
    case team(String)
    case adHoc
    case unsigned

    private static let adHocMarker = "Signature=adhoc"
    private static let teamPrefix = "TeamIdentifier="
    private static let noTeamValue = "not set"

    /// Reads the output of `codesign -dv --verbose=4`, which codesign writes to stderr.
    public static func parse(codesignOutput: String, exitStatus: Int32) -> SignatureInfo {
        guard exitStatus == 0 else { return .unsigned }
        if codesignOutput.contains(adHocMarker) { return .adHoc }
        let team = codesignOutput
            .split(separator: "\n")
            .first { $0.hasPrefix(teamPrefix) }
            .map { String($0.dropFirst(teamPrefix.count)) }
        guard let team, team != noTeamValue else { return .unsigned }
        return .team(team)
    }
}

public enum SigningPolicy {
    /// A bundle that was signed by a developer team must keep being signed by that team.
    /// Without this, a hijacked repo could swap in someone else's app unnoticed.
    public static func changesTeam(from previous: SignatureInfo?, to new: SignatureInfo) -> String? {
        guard case .team(let previousTeam)? = previous, new != .team(previousTeam) else { return nil }
        return previousTeam
    }
}
