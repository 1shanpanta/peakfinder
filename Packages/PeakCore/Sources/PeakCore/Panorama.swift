import Foundation

public struct Viewpoint: Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double
    /// Eye height in metres above sea level.
    public var eyeHeight: Double

    public init(latitude: Double, longitude: Double, eyeHeight: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.eyeHeight = eyeHeight
    }
}

public struct PeakRecord: Codable, Sendable, Hashable {
    public let name: String
    public let ele: Double
    public let lat: Double
    public let lon: Double

    public init(name: String, ele: Double, lat: Double, lon: Double) {
        self.name = name
        self.ele = ele
        self.lat = lat
        self.lon = lon
    }
}

public struct VisiblePeak: Sendable, Identifiable, Equatable {
    public var id: String { "\(name)@\(latitude),\(longitude)" }
    public let name: String
    public let elevation: Double
    public let latitude: Double
    public let longitude: Double
    public let distanceKm: Double
    /// Degrees clockwise from true north.
    public let bearing: Double
    /// Degrees above level to the summit, after Earth curvature and refraction.
    public let elevationAngle: Double
}

public struct Panorama: Sendable {
    public static let azimuthStep = 0.1
    public let viewpoint: Viewpoint
    public let rangeKm: Double
    /// Skyline angle in degrees above level, one value per `azimuthStep` degrees, starting at north.
    public let skyline: [Float]
    /// Visible peaks, highest first.
    public let peaks: [VisiblePeak]

    public func skylineAngle(atBearing bearing: Double) -> Double {
        let position = (bearing.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / Self.azimuthStep
        let lower = Int(position) % skyline.count
        let upper = (lower + 1) % skyline.count
        let fraction = position - position.rounded(.down)
        return Double(skyline[lower]) * (1 - fraction) + Double(skyline[upper]) * fraction
    }
}
