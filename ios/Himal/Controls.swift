import PeakCore
import SwiftUI

struct RoundButton: View {
    let systemName: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isActive ? .white : .black)
                .frame(width: 44, height: 44)
                .background(Circle().fill(isActive ? Color(red: 0.16, green: 0.62, blue: 0.93) : .white.opacity(0.95)))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .accessibilityLabel(systemName)
    }
}

/// A white dial that turns so its blue needle keeps pointing at north, with the heading in degrees under it.
struct CompassDial: View {
    let heading: Double
    let isFollowing: Bool
    let action: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Group {
            VStack(spacing: 3) {
                ZStack {
                    Circle().fill(isFollowing ? Color(red: 0.16, green: 0.62, blue: 0.93) : .white.opacity(0.95))
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let radius = size.width / 2 - 7
                        context.translateBy(x: center.x, y: center.y)
                        context.rotate(by: .degrees(-heading))
                        var north = Path()
                        north.move(to: CGPoint(x: 0, y: -radius))
                        north.addLine(to: CGPoint(x: 6, y: 2))
                        north.addLine(to: CGPoint(x: -6, y: 2))
                        north.closeSubpath()
                        var south = Path()
                        south.move(to: CGPoint(x: 0, y: radius))
                        south.addLine(to: CGPoint(x: 6, y: -2))
                        south.addLine(to: CGPoint(x: -6, y: -2))
                        south.closeSubpath()
                        context.fill(south, with: .color(isFollowing ? .white.opacity(0.55) : .black.opacity(0.35)))
                        context.fill(north, with: .color(isFollowing ? .white : Color(red: 0.16, green: 0.62, blue: 0.93)))
                    }
                }
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

                Text("\(Int(heading.rounded()) % 360)°")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.95)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onLongPressGesture(minimumDuration: 0.6, perform: onLongPress)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Compass, heading \(Int(heading.rounded())) degrees")
    }
}

struct LocationChip: View {
    let viewpoint: Viewpoint

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.circle.fill").foregroundStyle(.gray)
            Text(Self.description(viewpoint))
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .foregroundStyle(.black)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.95)))
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    static func description(_ viewpoint: Viewpoint) -> String {
        let lat = String(format: "%.5f°%@", abs(viewpoint.latitude), viewpoint.latitude >= 0 ? "N" : "S")
        let lon = String(format: "%.5f°%@", abs(viewpoint.longitude), viewpoint.longitude >= 0 ? "E" : "W")
        return "\(lat), \(lon) \(Int(viewpoint.eyeHeight.rounded())) m"
    }
}
