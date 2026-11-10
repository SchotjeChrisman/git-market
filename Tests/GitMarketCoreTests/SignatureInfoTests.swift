import XCTest
@testable import GitMarketCore

final class SignatureInfoTests: XCTestCase {
    func testTeamSignedBundleReportsItsTeam() {
        let output = "Identifier=com.example.app\nAuthority=Developer ID Application: Example (ABCDE12345)\nTeamIdentifier=ABCDE12345\n"
        XCTAssertEqual(SignatureInfo.parse(codesignOutput: output, exitStatus: 0), .team("ABCDE12345"))
    }

    func testAdHocSignatureIsRecognised() {
        let output = "Identifier=com.example.app\nSignature=adhoc\nTeamIdentifier=not set\n"
        XCTAssertEqual(SignatureInfo.parse(codesignOutput: output, exitStatus: 0), .adHoc)
    }

    func testFailedCodesignMeansUnsigned() {
        let output = "code object is not signed at all\n"
        XCTAssertEqual(SignatureInfo.parse(codesignOutput: output, exitStatus: 1), .unsigned)
    }

    func testSignedWithoutTeamCountsAsUnsigned() {
        XCTAssertEqual(SignatureInfo.parse(codesignOutput: "TeamIdentifier=not set\n", exitStatus: 0), .unsigned)
    }

    func testTeamChangeIsFlaggedOnlyWhenPreviousHadATeam() {
        XCTAssertEqual(SigningPolicy.changesTeam(from: .team("A"), to: .team("B")), "A")
        XCTAssertEqual(SigningPolicy.changesTeam(from: .team("A"), to: .adHoc), "A")
        XCTAssertEqual(SigningPolicy.changesTeam(from: .team("A"), to: .unsigned), "A")
        XCTAssertNil(SigningPolicy.changesTeam(from: .team("A"), to: .team("A")))
        XCTAssertNil(SigningPolicy.changesTeam(from: .adHoc, to: .team("B")))
        XCTAssertNil(SigningPolicy.changesTeam(from: .unsigned, to: .unsigned))
        XCTAssertNil(SigningPolicy.changesTeam(from: nil, to: .team("B")))
    }
}
