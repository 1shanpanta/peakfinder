import Foundation

/// Maps compass bearings and angles above level to screen points.
public struct ViewProjection: Sendable {
    public let heading: Double
    public let pitch: Double
    public let fieldOfView: Double
    public let width: Double
    public let height: Double
    /// Panorama mode puts true level at this fraction of the height. Camera mode follows the phone's pitch instead.
    public let levelAtFraction: Double?

    public init(heading: Double, pitch: Double, fieldOfView: Double, width: Double, height: Double, levelAtFraction: Double?) {
        self.heading = heading
        self.pitch = pitch
        self.fieldOfView = fieldOfView
        self.width = width
        self.height = height
        self.levelAtFraction = levelAtFraction
    }

    public var pointsPerDegree: Double { width / fieldOfView }

    public func x(bearing: Double) -> Double {
        width / 2 + Self.wrap(bearing - heading) * pointsPerDegree
    }

    public func y(angle: Double) -> Double {
        if let levelAtFraction { return height * levelAtFraction - angle * pointsPerDegree }
        return height / 2 - (angle - pitch) * pointsPerDegree
    }

    public func bearing(atX x: Double) -> Double {
        heading + (x - width / 2) / pointsPerDegree
    }

    /// Degrees in -180...180.
    public static func wrap(_ degrees: Double) -> Double {
        (degrees + 540).truncatingRemainder(dividingBy: 360) - 180
    }
}
