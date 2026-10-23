import Foundation

public enum CameraOptics {
    /// Horizontal field of view in degrees of a screen that shows the camera image filled to the screen.
    ///
    /// `longAxisFieldOfView` is the camera's field of view along the long side of the image, and `imageAspect` is
    /// long side over short side (4/3 for a full sensor, 16/9 for 1080p video). The filled image loses the part
    /// that overflows the screen, so a tall portrait screen sees less than the full short side.
    public static func horizontalFieldOfView(
        longAxisFieldOfView: Double, imageAspect: Double, screenWidth: Double, screenHeight: Double
    ) -> Double {
        let landscape = screenWidth >= screenHeight
        let (imageWidth, imageHeight) = landscape ? (imageAspect, 1.0) : (1.0, imageAspect)
        let scale = max(screenWidth / imageWidth, screenHeight / imageHeight)
        let visibleUnits = screenWidth / scale
        let tangentPerUnit = tan(longAxisFieldOfView * .pi / 360) / (imageAspect / 2)
        return 2 * atan(visibleUnits / 2 * tangentPerUnit) * 180 / .pi
    }
}
