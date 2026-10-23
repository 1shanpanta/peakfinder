import Foundation
import Testing
@testable import PeakCore

@Suite struct ViewProjectionTests {
    private func camera(heading: Double = 90, pitch: Double = 0, fov: Double = 40) -> ViewProjection {
        ViewProjection(heading: heading, pitch: pitch, fieldOfView: fov, width: 400, height: 800, levelAtFraction: nil)
    }

    @Test func theHeadingLandsInTheMiddleOfTheScreen() {
        #expect(camera().x(bearing: 90) == 200)
    }

    @Test func tenDegreesRightOfTheHeadingIsOneQuarterOfTheFieldAway() {
        // 40 degrees across 400 points is 10 points a degree.
        #expect(camera().x(bearing: 100) == 300)
        #expect(camera().x(bearing: 80) == 100)
    }

    @Test func bearingsWrapAcrossNorth() {
        let view = camera(heading: 355)

        #expect(abs(view.x(bearing: 5) - 300) < 1e-9)
        #expect(abs(view.x(bearing: 345) - 100) < 1e-9)
    }

    @Test func cameraModeKeepsThePitchLineInTheCentreAndHigherAnglesUp() {
        let view = camera(pitch: 5)

        #expect(view.y(angle: 5) == 400)
        #expect(view.y(angle: 6) == 390)
    }

    @Test func panoramaModePutsLevelAtItsFractionOfTheHeight() {
        let view = ViewProjection(heading: 0, pitch: 40, fieldOfView: 40, width: 400, height: 800, levelAtFraction: 0.75)

        #expect(view.y(angle: 0) == 600)
        #expect(view.y(angle: 3) == 570)
    }

    @Test func aScreenColumnMapsBackToItsBearing() {
        let view = camera(heading: 350)

        // 100 points right of centre is 10 degrees, which carries 350 round to north.
        #expect(abs(ViewProjection.wrap(view.bearing(atX: 300))) < 1e-9)
        #expect(view.bearing(atX: 200) == 350)
    }
}
