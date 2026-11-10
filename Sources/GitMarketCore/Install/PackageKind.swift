import Foundation

public enum PackageKind: String, Codable {
    case diskImage
    case archive
    case installerPackage

    public init?(fileName: String) {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "dmg": self = .diskImage
        case "zip": self = .archive
        case "pkg": self = .installerPackage
        default: return nil
        }
    }
}
