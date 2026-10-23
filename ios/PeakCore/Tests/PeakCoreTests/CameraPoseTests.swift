import Foundation
import Testing
@testable import PeakCore

@Suite struct CameraPoseTests {
    private func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }

    @Test func anUprightPhoneLooksLevelWithNoRoll() {
        // Held upright, gravity runs down the screen toward the bottom edge: y is -1.
        let pose = CameraPose(gravityX: 0, y: -1, z: 0)

        #expect(abs(pose.pitch) < 0.001)
        #expect(abs(pose.roll) < 0.001)
    }

    @Test func tippingTheTopTowardYouLooksUp() {
        // The screen turns to face down toward the floor, so gravity gains a +z part.
        let tilt = rad(30)
        let pose = CameraPose(gravityX: 0, y: -cos(tilt), z: sin(tilt))

        #expect(abs(pose.pitch - 30) < 0.001)
        #expect(abs(pose.roll) < 0.001)
    }

    @Test func tippingTheTopAwayFromYouLooksDown() {
        // The screen turns to face up, so gravity gains a -z part.
        let tilt = rad(20)
        let pose = CameraPose(gravityX: 0, y: -cos(tilt), z: -sin(tilt))

        #expect(abs(pose.pitch + 20) < 0.001)
    }

    @Test func rollingTheRightEdgeDownGivesPositiveRoll() {
        // The right edge points toward the floor, so gravity gains a +x part.
        let roll = rad(20)
        let pose = CameraPose(gravityX: sin(roll), y: -cos(roll), z: 0)

        #expect(abs(pose.roll - 20) < 0.001)
        #expect(abs(pose.pitch) < 0.001)
    }

    @Test func aPhoneLyingFlatLooksStraightDown() {
        let pose = CameraPose(gravityX: 0, y: 0, z: -1)

        #expect(abs(pose.pitch + 90) < 0.001)
    }
}
