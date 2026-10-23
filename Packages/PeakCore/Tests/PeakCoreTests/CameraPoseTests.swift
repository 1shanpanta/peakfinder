import Foundation
import Testing
@testable import PeakCore

@Suite struct CameraPoseTests {
    private func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }

    @Test func uprightPhoneFacingNorthReadsZeroEverywhere() {
        let pose = CameraPose(rotation: [0, -1, 0, 0, 0, 1, -1, 0, 0])

        #expect(abs(pose.bearing) < 0.001 || abs(pose.bearing - 360) < 0.001)
        #expect(abs(pose.pitch) < 0.001)
        #expect(abs(pose.roll) < 0.001)
    }

    @Test func uprightPhoneFacingEastReadsNinety() {
        let pose = CameraPose(rotation: [-1, 0, 0, 0, 0, 1, 0, 1, 0])

        #expect(abs(pose.bearing - 90) < 0.001)
        #expect(abs(pose.pitch) < 0.001)
    }

    @Test func tiltingTheCameraUpRaisesPitchAndKeepsHeading() {
        let tilt = rad(30)
        let pose = CameraPose(rotation: [0, -1, 0, -sin(tilt), 0, cos(tilt), -cos(tilt), 0, -sin(tilt)])

        #expect(abs(pose.pitch - 30) < 0.001)
        #expect(abs(pose.roll) < 0.001)
        #expect(abs(pose.bearing) < 0.001 || abs(pose.bearing - 360) < 0.001)
    }

    @Test func rollingTheRightEdgeDownGivesPositiveRoll() {
        let roll = rad(20)
        let pose = CameraPose(rotation: [0, -cos(roll), -sin(roll), 0, -sin(roll), cos(roll), -1, 0, 0])

        #expect(abs(pose.roll - 20) < 0.001)
        #expect(abs(pose.pitch) < 0.001)
    }

    @Test func aPhoneLyingFlatTakesItsHeadingFromTheTopEdge() {
        let pose = CameraPose(rotation: [-1, 0, 0, 0, -1, 0, 0, 0, 1])

        #expect(abs(pose.pitch + 90) < 0.001)
        #expect(abs(pose.bearing - 90) < 0.001)
    }
}
