import PeakCore
import SwiftUI

struct PanoramaCanvas: View {
    let panorama: Panorama
    let heading: Double
    let pitch: Double
    let fieldOfView: Double
    /// True draws the shaded ridges of the flat panorama. False draws only the outline over the camera.
    let drawsTerrain: Bool

    private static let labelSpacing = 25.0
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

    /// Puts the tallest skyline in any direction a little below mid-screen, so labels have sky above them.
    /// It depends on the whole circle, not the visible slice, so panning does not make the view jump.
    private func levelFraction(_ size: CGSize) -> Double {
        let tallest = max(Double(panorama.skyline.max() ?? 0), 0)
        return min(0.82, 0.58 + tallest * (size.width / fieldOfView) / size.height)
    }

    /// Far ridges first, each nearer one drawn darker over it.
    private func drawRidges(_ context: inout GraphicsContext, _ view: ViewProjection) {
        var profiles: [(Double) -> Double] = [panorama.skylineAngle(atBearing:)]
        profiles += panorama.layers.reversed().map { layer in { layer.angle(atBearing: $0) } }
        for (index, profile) in profiles.enumerated() {
            let depth = Double(index) / Double(max(profiles.count - 1, 1))
            var area = outline(profile, view)
            area.addLine(to: CGPoint(x: view.width + 2, y: view.height))
            area.addLine(to: CGPoint(x: -2, y: view.height))
            area.closeSubpath()
            context.fill(area, with: .color(Self.ridgeColor(depth: depth)))
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
            let shape = Path(roundedRect: rect, cornerRadius: 11)
            layer.fill(shape, with: .color(.white.opacity(0.95)))
            layer.stroke(shape, with: .color(.black.opacity(0.2)), lineWidth: 0.5)
            layer.draw(text, at: CGPoint(x: rect.minX + 9, y: rect.midY), anchor: .leading)
        }
    }

    /// Depth 0 is the farthest ridge, pale and hazy. Depth 1 is the nearest, dark.
    static func ridgeColor(depth: Double) -> Color {
        let far = (r: 0.68, g: 0.78, b: 0.89)
        let near = (r: 0.10, g: 0.14, b: 0.19)
        return Color(
            red: far.r + (near.r - far.r) * depth,
            green: far.g + (near.g - far.g) * depth,
            blue: far.b + (near.b - far.b) * depth
        )
    }
}
