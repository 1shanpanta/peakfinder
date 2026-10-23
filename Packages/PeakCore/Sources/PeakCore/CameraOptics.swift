import Foundation

public enum CameraOptics {
    /// Horizontal field of view in degrees of a screen that shows a 4:3 camera image filled to the screen.
    ///
    /// `longAxisFieldOfView` is the camera's field of view along the 4-unit side of the image. The filled image
    /// loses the part that overflows the screen, so a tall portrait screen sees less than the full short side.
    public static func horizontalFieldOfView(longAxisFieldOfView: Double, screenWidth: Double, screenHeight: Double) -> Double {
        let (longUnits, shortUnits) = (4.0, 3.0)
        let landscape = screenWidth >= screenHeight
        let (imageWidth, imageHeight) = landscape ? (longUnits, shortUnits) : (shortUnits, longUnits)
        let scale = max(screenWidth / imageWidth, screenHeight / imageHeight)
        let visibleUnits = screenWidth / scale
        let tangentPerUnit = tan(longAxisFieldOfView * .pi / 360) / (longUnits / 2)
        return 2 * atan(visibleUnits / 2 * tangentPerUnit) * 180 / .pi
    }
}
