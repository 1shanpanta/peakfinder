import PeakCore
import SwiftUI

struct ContentView: View {
    @Bindable var store: PanoramaStore
    @State private var dragStartHeading: Double?
    @State private var zoomStart: Double?

    private static let sky = LinearGradient(
        colors: [Color(red: 0.33, green: 0.56, blue: 0.82), Color(red: 0.86, green: 0.92, blue: 0.97)],
        startPoint: .top, endPoint: .init(x: 0.5, y: 0.75)
    )

    var body: some View {
        GeometryReader { geometry in
            let fieldOfView = store.visibleFieldOfView(screen: geometry.size)
            ZStack {
                background
                if let panorama = store.panorama {
                    PanoramaCanvas(
                        panorama: panorama, heading: store.heading, pitch: store.pitch,
                        fieldOfView: fieldOfView, drawsTerrain: !store.usesCamera
                    )
                    .rotationEffect(.degrees(store.usesCamera ? -store.roll : 0))
                }
                overlay(insets: geometry.safeAreaInsets)
            }
            .contentShape(Rectangle())
            .gesture(pan(pointsPerDegree: geometry.size.width / fieldOfView))
            .gesture(zoom)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .task { store.start() }
    }

    @ViewBuilder private var background: some View {
        if store.usesCamera {
            CameraPreview { store.setLens($0) }
        } else {
            Self.sky
        }
    }

    private func overlay(insets: EdgeInsets) -> some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    RoundButton(systemName: "camera.fill", isActive: store.usesCamera) { store.toggleCamera() }
                    Spacer()
                    CompassDial(
                        heading: store.heading, isFollowing: store.followsCompass,
                        action: { store.followsCompass.toggle() },
                        onLongPress: { store.showsDiagnostics.toggle() }
                    )
                }
                Spacer()
                if store.showsDiagnostics { diagnostics }
                if let panorama = store.panorama {
                    LocationChip(viewpoint: panorama.viewpoint)
                }
            }
            .padding(.horizontal, max(16, insets.leading, insets.trailing))
            .padding(.top, max(12, insets.top))
            .padding(.bottom, max(12, insets.bottom))

            statusMessage
        }
    }

    /// Raw sensor values, shown by a long press on the compass dial, for checking the app against a real phone.
    private var diagnostics: some View {
        let accuracy = store.compassAccuracy.map { $0 < 0 ? "invalid" : String(format: "±%.0f°", $0) } ?? "none"
        let lens = store.lens
        return Text(String(
            format: "heading %.1f°  accuracy %@\npitch %.1f°  roll %.1f°\nlens %.1f° long side, aspect %.2f\nfollowing compass %@",
            store.heading, accuracy, store.pitch, store.roll, lens.longAxisFieldOfView, lens.imageAspect,
            store.followsCompass ? "yes" : "no"
        ))
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.7)))
        .padding(.bottom, 6)
    }

    @ViewBuilder private var statusMessage: some View {
        switch store.status {
        case .loading:
            Label("Loading terrain", systemImage: "mountain.2.fill")
                .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        case .failed(let reason):
            Text(reason).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        case .ready:
            if store.isDemo {
                Text("Demo view from Nagarkot. Himal only has Nepal.")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 70)
            }
        }
    }

    private func pan(pointsPerDegree: Double) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = dragStartHeading ?? store.heading
                dragStartHeading = start
                store.panHeading(to: start - value.translation.width / pointsPerDegree)
            }
            .onEnded { _ in dragStartHeading = nil }
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? store.fieldOfView
                zoomStart = start
                store.fieldOfView = min(100, max(8, start / value.magnification))
            }
            .onEnded { _ in zoomStart = nil }
    }
}
