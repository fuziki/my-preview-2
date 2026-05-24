import Foundation

public struct ExifInfo: Sendable {
    public let iso: String?
    public let focalLength: String?
    public let exposureValue: String?
    public let fNumber: String?
    public let shutterSpeed: String?
    public let flashFired: Bool

    nonisolated public init(
        iso: String?,
        focalLength: String?,
        exposureValue: String?,
        fNumber: String?,
        shutterSpeed: String?,
        flashFired: Bool
    ) {
        self.iso = iso
        self.focalLength = focalLength
        self.exposureValue = exposureValue
        self.fNumber = fNumber
        self.shutterSpeed = shutterSpeed
        self.flashFired = flashFired
    }
}
