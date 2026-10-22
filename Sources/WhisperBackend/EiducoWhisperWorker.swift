import AVFoundation
import Foundation
import whisper

/// Local, serial Whisper worker. Add these sources to the iOS app target and link
/// the `whisper` XCFramework built from ggml-org/whisper.cpp for iOS/Metal.
public actor EiducoWhisperWorker {
    private var engine: WhisperCppEngine?
    private var courseAccess: ScopedURLAccess?
    private var isProcessing = false
    private nonisolated let cancellation = CancellationFlag()

    public init() {}

    /// Loads the user-selected GGML model into memory. The model is never bundled
    /// with the app; the device-only Metal backend remains enabled on real iPads.
    public func loadModel(from modelURL: URL) throws {
        guard !isProcessing else { throw WorkerStateError.busy }
        let access = ScopedURLAccess(modelURL)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              modelURL.pathExtension.lowercased() == "bin",
              let size = try? modelURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0 else {
            throw EiducoWhisperError.modelFileUnavailable
        }

        let loaded = try WhisperCppEngine(modelPath: modelURL.path, cancellation: cancellation)
        engine = loaded
        _ = access // Keep security-scoped access alive until loading has returned.
    }

    /// Scans direct child lesson folders. Existing raw VTT files are considered
    /// already transcribed; the app does not infer OCR or packaging completion.
    public func scanCourse(at folderURL: URL) throws -> [EiducoLesson] {
        guard !isProcessing else { throw WorkerStateError.busy }
        return try scanCourseUnlocked(at: folderURL)
    }

    private func scanCourseUnlocked(at folderURL: URL) throws -> [EiducoLesson] {
        let access = ScopedURLAccess(folderURL)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw EiducoWhisperError.courseFolderUnavailable
        }

        let directories = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }

        let lessons = directories.map { directory -> EiducoLesson in
            let transcript = directory.appendingPathComponent("trascrizione_raw.vtt")
            let transcriptAttributes = try? FileManager.default.attributesOfItem(atPath: transcript.path)
            let transcriptSize = (transcriptAttributes?[.size] as? NSNumber)?.intValue ?? 0
            if transcriptSize > 20 {
                return EiducoLesson(directoryURL: directory, audioURL: nil, state: .transcriptPresent)
            }

            let audioURL = ["audio.mp4", "audio.ogg", "audio.mp3"]
                .map { directory.appendingPathComponent($0) }
                .first { url in
                    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else { return false }
                    return values.isRegularFile == true && (values.fileSize ?? 0) > 0
                }

            return EiducoLesson(
                directoryURL: directory,
                audioURL: audioURL,
                state: audioURL == nil ? .missingAudio : .pending
            )
        }

        courseAccess = access
        return lessons.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
    }

    /// Transcribes pending lessons newest-first so the iPad complements the
    /// Mac batch, which processes the same course oldest-first.
    public func processPendingLessons(
        in folderURL: URL,
        progress: @escaping @Sendable (EiducoWorkerProgress) -> Void
    ) async throws -> EiducoBatchSummary {
        guard let engine else { throw WorkerStateError.modelNotLoaded }
        guard !isProcessing else { throw WorkerStateError.busy }

        isProcessing = true
        cancellation.reset()
        defer { isProcessing = false }

        return try await withTaskCancellationHandler {
            try await process(folderURL: folderURL, engine: engine, progress: progress)
        } onCancel: {
            self.cancel()
        }
    }

    /// Can be called while Whisper is inside its C inference call.
    public nonisolated func cancel() {
        cancellation.cancel()
    }

    private func process(
        folderURL: URL,
        engine: WhisperCppEngine,
        progress: @escaping @Sendable (EiducoWorkerProgress) -> Void
    ) async throws -> EiducoBatchSummary {
        let lessons = try scanCourseUnlocked(at: folderURL)
        let pending = lessons.filter { $0.state == .pending }
        let skipped = lessons.count - pending.count
        var completed = 0

        for lesson in pending {
            try Task.checkCancellation()
            if cancellation.isCancelled { throw CancellationError() }
            guard let audioURL = lesson.audioURL else { continue }
            let completedBeforeLesson = completed

            progress(EiducoWorkerProgress(
                lessonTitle: lesson.title,
                completedLessons: completed,
                totalLessons: pending.count,
                stage: .decodingAudio,
                fraction: 0
            ))
            let samples = try await EiducoAudioDecoder.decodeMono16kFloat(from: audioURL)
            if cancellation.isCancelled { throw CancellationError() }

            let transcript = try engine.transcribe(samples: samples) { percent in
                progress(EiducoWorkerProgress(
                    lessonTitle: lesson.title,
                    completedLessons: completedBeforeLesson,
                    totalLessons: pending.count,
                    stage: .transcribing,
                    fraction: Double(percent) / 100
                ))
            }

            try Task.checkCancellation()
            if cancellation.isCancelled { throw CancellationError() }
            progress(EiducoWorkerProgress(
                lessonTitle: lesson.title,
                completedLessons: completed,
                totalLessons: pending.count,
                stage: .writingFiles,
                fraction: 1
            ))
            try EiducoTranscriptWriter.write(transcript, to: lesson.directoryURL)
            completed += 1
        }

        return EiducoBatchSummary(discovered: lessons.count, transcribed: completed, skipped: skipped)
    }
}

private enum WorkerStateError: LocalizedError {
    case busy
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .busy: return "La coda è già in esecuzione."
        case .modelNotLoaded: return "Seleziona e carica prima il modello Whisper."
        }
    }
}

private final class ScopedURLAccess {
    private let url: URL
    private let didStart: Bool

    init(_ url: URL) {
        self.url = url
        didStart = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if didStart { url.stopAccessingSecurityScopedResource() }
    }
}

private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func reset() {
        lock.lock()
        value = false
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class ProgressReporter: @unchecked Sendable {
    private let report: @Sendable (Int) -> Void

    init(report: @escaping @Sendable (Int) -> Void) {
        self.report = report
    }

    func call(_ value: Int32) {
        report(Int(value))
    }
}

private final class WhisperCppEngine {
    private let context: OpaquePointer
    private let cancellation: CancellationFlag
    private let modelPath: String

    init(modelPath: String, cancellation: CancellationFlag = CancellationFlag()) throws {
        self.modelPath = modelPath
        self.cancellation = cancellation
        var params = whisper_context_default_params()
#if targetEnvironment(simulator)
        params.use_gpu = false
#else
        params.flash_attn = true
#endif
        guard let context = modelPath.withCString({ whisper_init_from_file_with_params($0, params) }) else {
            throw EiducoWhisperError.modelLoadFailed
        }
        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    func transcribe(
        samples: [Float],
        progress: @escaping @Sendable (Int) -> Void
    ) throws -> EiducoTranscript {
        guard let sampleCount = Int32(exactly: samples.count) else {
            throw EiducoWhisperError.audioDecodeFailed("audio troppo lungo per whisper.cpp")
        }

        let reporter = ProgressReporter(report: progress)
        let progressUserData = Unmanaged.passUnretained(reporter).toOpaque()
        let cancellationUserData = Unmanaged.passUnretained(cancellation).toOpaque()
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount))
        params.translate = false
        params.no_context = true
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.progress_callback = { _, _, value, userData in
            guard let userData else { return }
            Unmanaged<ProgressReporter>.fromOpaque(userData).takeUnretainedValue().call(value)
        }
        params.progress_callback_user_data = progressUserData
        params.abort_callback = { userData in
            guard let userData else { return false }
            return Unmanaged<CancellationFlag>.fromOpaque(userData).takeUnretainedValue().isCancelled
        }
        params.abort_callback_user_data = cancellationUserData

        let result = "it".withCString { language in
            params.language = language
            return samples.withUnsafeBufferPointer { buffer in
                whisper_full(context, params, buffer.baseAddress, sampleCount)
            }
        }
        if cancellation.isCancelled { throw CancellationError() }
        guard result == 0 else { throw EiducoWhisperError.transcriptionFailed }

        let count = whisper_full_n_segments(context)
        var segments: [EiducoTranscriptSegment] = []
        segments.reserveCapacity(Int(count))
        for index in 0..<count {
            let start = Double(whisper_full_get_segment_t0(context, index)) / 100
            let end = Double(whisper_full_get_segment_t1(context, index)) / 100
            let text = String(cString: whisper_full_get_segment_text(context, index))
            segments.append(EiducoTranscriptSegment(start: start, end: end, text: text))
        }
        guard !segments.isEmpty else { throw EiducoWhisperError.missingOutput }
        let audio = JSONDocumentDimensions(
            context: whisper_model_n_audio_ctx(context),
            state: whisper_model_n_audio_state(context),
            head: whisper_model_n_audio_head(context),
            layer: whisper_model_n_audio_layer(context)
        )
        let text = JSONDocumentDimensions(
            context: whisper_model_n_text_ctx(context),
            state: whisper_model_n_text_state(context),
            head: whisper_model_n_text_head(context),
            layer: whisper_model_n_text_layer(context)
        )
        let detectedLanguage = String(cString: whisper_lang_str(whisper_full_lang_id(context)))
        return EiducoTranscript(
            segments: segments,
            metadata: EiducoTranscriptMetadata(
                systemInfo: String(cString: whisper_print_system_info()),
                modelType: String(cString: whisper_model_type_readable(context)),
                multilingual: whisper_is_multilingual(context) != 0,
                vocabularySize: whisper_model_n_vocab(context),
                audioContext: audio.context,
                audioState: audio.state,
                audioHeads: audio.head,
                audioLayers: audio.layer,
                textContext: text.context,
                textState: text.state,
                textHeads: text.head,
                textLayers: text.layer,
                melCount: whisper_model_n_mels(context),
                modelTypeCode: whisper_model_ftype(context),
                modelPath: modelPath,
                language: "it",
                detectedLanguage: detectedLanguage
            )
        )
    }
}

private struct JSONDocumentDimensions {
    let context: Int32
    let state: Int32
    let head: Int32
    let layer: Int32
}
