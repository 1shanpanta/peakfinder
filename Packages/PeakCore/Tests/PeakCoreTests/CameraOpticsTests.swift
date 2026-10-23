import Foundation
import Testing
@testable import PeakCore

@Suite struct CameraOpticsTests {
    private func fov(aspect: Double, width: Double, height: Double) -> Double {
        CameraOptics.horizontalFieldOfView(longAxisFieldOfView: 69.4, imageAspect: aspect, screenWidth: width, screenHeight: height)
    }

    @Test func aWideLandscapeScreenSeesTheFullLongSideOfTheImage() {
        #expect(abs(fov(aspect: 4.0 / 3, width: 844, height: 390) - 69.4) < 0.01)
        #expect(abs(fov(aspect: 16.0 / 9, width: 844, height: 390) - 69.4) < 0.01)
    }

    @Test func aTallPortraitScreenSeesOnlyACropOfTheShortSide() {
        // The image fills the screen height, so tan(half width) is tan(34.7 degrees) * 390 / 844. That is 35.4 degrees.
        // The image shape does not matter while the height decides the fit.
        #expect(abs(fov(aspect: 4.0 / 3, width: 390, height: 844) - 35.4) < 0.2)
        #expect(abs(fov(aspect: 16.0 / 9, width: 390, height: 844) - 35.4) < 0.2)
    }

    @Test func aScreenAsWideAsTheImageSeesTheWholeShortSide() {
        // 4:3 short side: 2 * atan(tan(34.7 degrees) * 3 / 4) is 54.8 degrees.
        #expect(abs(fov(aspect: 4.0 / 3, width: 300, height: 400) - 54.8) < 0.2)
        // 16:9 short side: 2 * atan(tan(34.7 degrees) * 9 / 16) is 42.6 degrees. A 3:4 screen is wider than 9:16.
        #expect(abs(fov(aspect: 16.0 / 9, width: 300, height: 400) - 42.6) < 0.2)
    }
}
