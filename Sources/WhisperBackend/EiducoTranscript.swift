import Foundation

public struct EiducoTranscriptSegment: Codable, Sendable, Equatable {
    public let start: Double
    public let end: Double
    public let text: String

    public init(start: Double, end: Double, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}

struct EiducoTranscriptMetadata: Sendable {
    let systemInfo: String
    let modelType: String
    let multilingual: Bool
    let vocabularySize: Int32
    let audioContext: Int32
    let audioState: Int32
    let audioHeads: Int32
    let audioLayers: Int32
    let textContext: Int32
    let textState: Int32
    let textHeads: Int32
    let textLayers: Int32
    let melCount: Int32
    let modelTypeCode: Int32
    let modelPath: String
    let language: String
    let detectedLanguage: String
}

struct EiducoTranscript: Sendable {
    let segments: [EiducoTranscriptSegment]
    let metadata: EiducoTranscriptMetadata
}

public struct EiducoLesson: Identifiable, Sendable, Equatable {
    public enum State: String, Sendable {
        case pending
        case transcriptPresent
        case missingAudio
    }

    public let directoryURL: URL
    public let audioURL: URL?
    public let state: State

    public var id: String { directoryURL.standardizedFileURL.path }
    public var title: String { directoryURL.lastPathComponent }

    public init(directoryURL: URL, audioURL: URL?, state: State) {
        self.directoryURL = directoryURL
        self.audioURL = audioURL
        self.state = state
    }
}

public struct EiducoWorkerProgress: Sendable, Equatable {
    public enum Stage: String, Sendable {
        case decodingAudio
        case transcribing
        case writingFiles
    }

    public let lessonTitle: String
    public let completedLessons: Int
    public let totalLessons: Int
    public let stage: Stage
    public let fraction: Double

    public init(
        lessonTitle: String,
        completedLessons: Int,
        totalLessons: Int,
        stage: Stage,
        fraction: Double
    ) {
        self.lessonTitle = lessonTitle
        self.completedLessons = completedLessons
        self.totalLessons = totalLessons
        self.stage = stage
        self.fraction = min(1, max(0, fraction))
    }
}

public struct EiducoBatchSummary: Sendable, Equatable {
    public let discovered: Int
    public let transcribed: Int
    public let skipped: Int
}

public enum EiducoWhisperError: LocalizedError {
    case modelFileUnavailable
    case modelLoadFailed
    case courseFolderUnavailable
    case noAudioTrack(URL)
    case audioDecodeFailed(String)
    case transcriptionFailed
    case missingOutput

    public var errorDescription: String? {
        switch self {
        case .modelFileUnavailable:
            return "Il modello Whisper selezionato non è un file GGML leggibile."
        case .modelLoadFailed:
            return "whisper.cpp non è riuscito a caricare il modello. Verifica che sia ggml-large-v3 e che ci sia spazio sufficiente."
        case .courseFolderUnavailable:
            return "La cartella del corso non è accessibile. Selezionala di nuovo da File."
        case let .noAudioTrack(url):
            return "Nessuna traccia audio leggibile in \(url.lastPathComponent)."
        case let .audioDecodeFailed(message):
            return "Decodifica audio non riuscita: \(message)"
        case .transcriptionFailed:
            return "whisper.cpp non ha completato la trascrizione."
        case .missingOutput:
            return "Trascrizione terminata senza produrre segmenti."
        }
    }
}
