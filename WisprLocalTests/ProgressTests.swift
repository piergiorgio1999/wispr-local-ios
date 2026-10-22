import XCTest
import WhisperBackend

final class ProgressTests: XCTestCase {
    func testProgressFractionIsBounded() {
        let progress = EiducoWorkerProgress(
            lessonTitle: "Lezione",
            completedLessons: 0,
            totalLessons: 1,
            stage: .transcribing,
            fraction: 1.5
        )

        XCTAssertEqual(progress.fraction, 1)
    }
}
