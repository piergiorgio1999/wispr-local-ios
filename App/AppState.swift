import Foundation
import SwiftUI
import WhisperBackend

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var modelName: String?
    @Published private(set) var isLoadingModel = false
    @Published private(set) var modelReady = false
    @Published private(set) var courseName: String?
    @Published private(set) var lessons: [EiducoLesson] = []
    @Published private(set) var isRunning = false
    @Published private(set) var progress: EiducoWorkerProgress?
    @Published private(set) var summary: EiducoBatchSummary?
    @Published private(set) var statusMessage: String?
    @Published var errorMessage: String?

    private let worker = EiducoWhisperWorker()
    private var modelURL: URL?
    private var courseURL: URL?
    private var batchTask: Task<Void, Never>?

    private enum BookmarkKey {
        static let model = "selectedModelBookmark"
        static let course = "selectedCourseBookmark"
    }

    init() {
        modelURL = restoreBookmark(forKey: BookmarkKey.model)
        courseURL = restoreBookmark(forKey: BookmarkKey.course)
        modelName = modelURL?.lastPathComponent
        courseName = courseURL?.lastPathComponent
        if modelURL != nil {
            loadSelectedModel()
        }
        if courseURL != nil {
            refreshLessons()
        }
    }

    var pendingCount: Int { lessons.filter { $0.state == .pending }.count }
    var transcribedCount: Int { lessons.filter { $0.state == .transcriptPresent }.count }
    var missingAudioCount: Int { lessons.filter { $0.state == .missingAudio }.count }

    func chooseModel(_ url: URL) {
        guard !isRunning else { return }
        errorMessage = nil
        do {
            try saveBookmark(url, forKey: BookmarkKey.model)
            modelURL = url
            modelName = url.lastPathComponent
            modelReady = false
            summary = nil
            loadSelectedModel()
        } catch {
            errorMessage = "Non riesco a conservare l'accesso al modello: \(error.localizedDescription)"
        }
    }

    func chooseCourse(_ url: URL) {
        guard !isRunning else { return }
        errorMessage = nil
        do {
            try saveBookmark(url, forKey: BookmarkKey.course)
            courseURL = url
            courseName = url.lastPathComponent
            summary = nil
            refreshLessons()
        } catch {
            errorMessage = "Non riesco a conservare l'accesso alla cartella: \(error.localizedDescription)"
        }
    }

    func refreshLessons() {
        guard let courseURL else { return }
        Task {
            do {
                lessons = try await worker.scanCourse(at: courseURL)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startBatch() {
        guard modelReady, let courseURL, !isRunning else { return }
        isRunning = true
        progress = nil
        summary = nil
        statusMessage = nil
        batchTask = Task {
            defer {
                isRunning = false
                batchTask = nil
            }
            do {
                let result = try await worker.processPendingLessons(in: courseURL) { [weak self] value in
                    Task { @MainActor in self?.progress = value }
                }
                summary = result
                statusMessage = "Coda terminata. Lezioni trascritte: \(result.transcribed)."
                lessons = try await worker.scanCourse(at: courseURL)
            } catch is CancellationError {
                statusMessage = "Elaborazione interrotta. Puoi riprendere: le lezioni già trascritte verranno saltate."
                lessons = (try? await worker.scanCourse(at: courseURL)) ?? lessons
            } catch {
                errorMessage = error.localizedDescription
                lessons = (try? await worker.scanCourse(at: courseURL)) ?? lessons
            }
        }
    }

    func cancelBatch() {
        worker.cancel()
        batchTask?.cancel()
    }

    private func loadSelectedModel() {
        guard let modelURL else { return }
        isLoadingModel = true
        modelReady = false
        Task {
            defer { isLoadingModel = false }
            do {
                try await worker.loadModel(from: modelURL)
                modelReady = true
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveBookmark(_ url: URL, forKey key: String) throws {
        let bookmark = try url.bookmarkData()
        UserDefaults.standard.set(bookmark, forKey: key)
    }

    private func restoreBookmark(forKey key: String) -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: key) else { return nil }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            if isStale { try saveBookmark(url, forKey: key) }
            return url
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }
}
