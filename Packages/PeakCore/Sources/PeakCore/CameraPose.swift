import Foundation

/// How the back camera is tilted, taken from the gravity vector in device axes.
///
/// Device axes: x to the right edge, y to the top edge, z out of the screen. CoreMotion reports gravity in these
/// axes in units of g, pointing down. That needs no reference frame, so the maths has no convention to get wrong.
public struct CameraPose: Sendable, Equatable {
    /// Degrees above level the back camera looks. Negative looks down.
    public let pitch: Double
    /// Degrees the right edge of the phone is tilted down. Zero when the phone is level.
    public let roll: Double

    public init(gravityX x: Double, y: Double, z: Double) {
        // The back camera looks along -z, and "up" in the world is minus gravity.
        pitch = asin(min(1, max(-1, z))) * 180 / .pi
        roll = atan2(x, -y) * 180 / .pi
    }
}
