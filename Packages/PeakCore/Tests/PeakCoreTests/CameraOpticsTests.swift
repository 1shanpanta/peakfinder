import Foundation
import Testing
@testable import PeakCore

@Suite struct CameraOpticsTests {
    @Test func aWideLandscapeScreenSeesTheFullLongSideOfTheImage() {
        let fov = CameraOptics.horizontalFieldOfView(longAxisFieldOfView: 69.4, screenWidth: 844, screenHeight: 390)

        #expect(abs(fov - 69.4) < 0.01)
    }

    @Test func aTallPortraitScreenSeesOnlyACropOfTheShortSide() {
        // 69.4 degrees over the long side; a 390 by 844 screen crops the image to 35.4 degrees across.
        let fov = CameraOptics.horizontalFieldOfView(longAxisFieldOfView: 69.4, screenWidth: 390, screenHeight: 844)

        #expect(abs(fov - 35.4) < 0.2)
    }

    @Test func aFourByThreeScreenSeesTheWholeShortSide() {
        // 2 * atan(tan(34.7 degrees) * 3 / 4) is 54.8 degrees.
        let fov = CameraOptics.horizontalFieldOfView(longAxisFieldOfView: 69.4, screenWidth: 300, screenHeight: 400)

        #expect(abs(fov - 54.8) < 0.2)
    }
}
