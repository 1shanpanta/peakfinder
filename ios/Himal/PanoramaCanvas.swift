import PeakCore
import SwiftUI

struct PanoramaCanvas: View {
    let panorama: Panorama
    let heading: Double
    let pitch: Double
    let fieldOfView: Double
    /// True draws the shaded ridges of the flat panorama. False draws only the outline over the camera.
    let drawsTerrain: Bool

    private static let labelSpacing = 30.0
    private static let labelTilt = Angle.degrees(-62)

    var body: some View {
        Canvas { context, size in
            let view = ViewProjection(
                heading: heading, pitch: pitch, fieldOfView: fieldOfView, width: size.width, height: size.height,
                levelAtFraction: drawsTerrain ? levelFraction(size) : nil
            )
            if drawsTerrain { drawRidges(&context, view) }
            drawSkyline(&context, view)
            drawLabels(&context, view)
        }
    }

    /// Puts the tallest skyline in any direction near mid-screen, so labels have sky above them and the ridges
    /// get the rest of the height. It depends on the whole circle, not the visible slice, so panning does not jump.
    private func levelFraction(_ size: CGSize) -> Double {
        let tallest = max(Double(panorama.skyline.max() ?? 0), 0)
        return min(0.82, 0.52 + tallest * (size.width / fieldOfView) / size.height)
    }

    /// Far ridges first, each nearer one drawn darker over it. Each ridge is paler at its crest, as if in haze.
    private func drawRidges(_ context: inout GraphicsContext, _ view: ViewProjection) {
        var ridges: [(profile: (Double) -> Double, rangeKm: Double)] = [(panorama.skylineAngle(atBearing:), panorama.rangeKm)]
        ridges += panorama.layers.reversed().map { layer in ({ layer.angle(atBearing: $0) }, layer.rangeKm) }
        for (index, ridge) in ridges.enumerated() {
            let depth = Double(index) / Double(max(ridges.count - 1, 1))
            let edge = outline(Self.softened(ridge.profile, spread: Self.spread(rangeKm: ridge.rangeKm)), view)
            var area = edge
            area.addLine(to: CGPoint(x: view.width + 2, y: view.height))
            area.addLine(to: CGPoint(x: -2, y: view.height))
            area.closeSubpath()
            let crest = edge.boundingRect.minY
            let haze = Gradient(colors: [Self.crestColor(depth: depth), Self.baseColor(depth: depth)])
            context.fill(area, with: .linearGradient(
                haze, startPoint: CGPoint(x: 0, y: crest), endPoint: CGPoint(x: 0, y: min(view.height, crest + view.height * 0.4))
            ))
        }
    }

    /// Averages a few nearby bearings. Near terrain comes from coarse cells and shows as steps, which this rounds off.
    private static func softened(_ profile: @escaping (Double) -> Double, spread: Double) -> (Double) -> Double {
        guard spread > 0 else { return profile }
        let offsets = [-1.0, -0.5, 0, 0.5, 1.0].map { $0 * spread }
        return { bearing in offsets.map { profile(bearing + $0) }.reduce(0, +) / Double(offsets.count) }
    }

    private static func spread(rangeKm: Double) -> Double {
        switch rangeKm {
        case ...4: 0.5
        case ...12: 0.3
        case ...30: 0.15
        default: 0
        }
    }

    private func drawSkyline(_ context: inout GraphicsContext, _ view: ViewProjection) {
        let line = outline(panorama.skylineAngle(atBearing:), view)
        context.stroke(line, with: .color(.black.opacity(drawsTerrain ? 0.55 : 0.85)), lineWidth: drawsTerrain ? 1 : 1.6)
    }

    private func outline(_ profile: (Double) -> Double, _ view: ViewProjection) -> Path {
        var path = Path()
        let step = 2.0
        for x in stride(from: -step, through: view.width + step, by: step) {
            let point = CGPoint(x: x, y: view.y(angle: profile(view.bearing(atX: x))))
            if path.isEmpty { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func drawLabels(_ context: inout GraphicsContext, _ view: ViewProjection) {
        var placed: [Double] = []
        let reach = fieldOfView / 2 + 12
        for peak in panorama.peaks where abs(ViewProjection.wrap(peak.bearing - view.heading)) < reach {
            let x = view.x(bearing: peak.bearing)
            guard !placed.contains(where: { abs($0 - x) < Self.labelSpacing }) else { continue }
            placed.append(x)

            let foot = view.y(angle: peak.elevationAngle)
            let top = min(foot, view.y(angle: panorama.skylineAngle(atBearing: peak.bearing))) - 22
            var leader = Path()
            leader.move(to: CGPoint(x: x, y: foot))
            leader.addLine(to: CGPoint(x: x, y: top))
            context.stroke(leader, with: .color(.black.opacity(0.7)), lineWidth: 0.8)
            drawPill(&context, peak: peak, at: CGPoint(x: x, y: top))
        }
    }

    private func drawPill(_ context: inout GraphicsContext, peak: VisiblePeak, at origin: CGPoint) {
        let name = Text(peak.name).font(.system(size: 13, weight: .semibold)).foregroundColor(.black)
        let height = Text(" \(Int(peak.elevation))").font(.system(size: 9.5, weight: .semibold)).foregroundColor(.black.opacity(0.6))
        let text = context.resolve(name + height)
        let width = text.measure(in: CGSize(width: 400, height: 40)).width + 18
        let rect = CGRect(x: -11, y: -22, width: width, height: 22)

        context.drawLayer { layer in
            layer.translateBy(x: origin.x, y: origin.y)
            layer.rotate(by: Self.labelTilt)
            let shape = Path(roundedRect: rect, cornerRadius: 6)
            layer.fill(shape, with: .color(.white.opacity(0.95)))
            layer.stroke(shape, with: .color(.black.opacity(0.2)), lineWidth: 0.5)
            layer.draw(text, at: CGPoint(x: rect.minX + 9, y: rect.midY), anchor: .leading)
        }
    }

    private typealias RGB = (r: Double, g: Double, b: Double)
    private static let farRidge: RGB = (0.68, 0.78, 0.89)
    private static let nearRidge: RGB = (0.10, 0.14, 0.19)
    private static let horizonHaze: RGB = (0.86, 0.92, 0.97)
    private static let shade: RGB = (0.03, 0.05, 0.08)

    private static func mix(_ a: RGB, _ b: RGB, _ amount: Double) -> RGB {
        (a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount, a.b + (b.b - a.b) * amount)
    }

    /// Depth 0 is the farthest ridge, pale and hazy. Depth 1 is the nearest, dark.
    private static func ridge(depth: Double) -> RGB { mix(farRidge, nearRidge, depth) }

    /// The top of a far ridge fades toward the horizon haze. A near ridge keeps its own colour.
    static func crestColor(depth: Double) -> Color {
        let c = mix(ridge(depth: depth), horizonHaze, 0.5 * (1 - depth))
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    /// The foot of a near ridge sinks toward black, so the nearest ground is not one flat block.
    static func baseColor(depth: Double) -> Color {
        let c = mix(ridge(depth: depth), shade, 0.35 * depth)
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}
