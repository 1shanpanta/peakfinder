import Foundation

/// Where the back camera points, taken from a device rotation matrix.
///
/// The matrix is row-major and maps a reference frame (x north, y west, z up) into the device frame,
/// the layout of CoreMotion's `xTrueNorthZVertical` attitude. Its rows are the device axes in world terms.
public struct CameraPose: Sendable, Equatable {
    /// Degrees clockwise from true north that the back camera faces.
    public let bearing: Double
    /// Degrees above level the back camera looks.
    public let pitch: Double
    /// Degrees the right edge of the phone is tilted down. Zero when the phone is level.
    public let roll: Double

    public init(rotation m: [Double]) {
        precondition(m.count == 9, "a rotation matrix has nine entries")
        let forward = (x: -m[6], y: -m[7], z: -m[8])
        let right = (x: m[0], y: m[1], z: m[2])
        let up = (x: m[3], y: m[4], z: m[5])

        // Flat on a table the camera looks straight down and has no heading, so use the top edge instead.
        let flat = abs(forward.z) > 0.95
        let heading = flat ? (north: up.x, west: up.y) : (north: forward.x, west: forward.y)
        bearing = (atan2(-heading.west, heading.north) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        pitch = asin(min(1, max(-1, forward.z))) * 180 / .pi
        roll = atan2(-right.z, up.z) * 180 / .pi
    }
}
