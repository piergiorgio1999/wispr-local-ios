import Foundation

enum EiducoTranscriptWriter {
    private struct JSONDocument: Encodable {
        struct Model: Encodable {
            struct Dimensions: Encodable {
                let ctx: Int32
                let state: Int32
                let head: Int32
                let layer: Int32
            }

            let type: String
            let multilingual: Bool
            let vocab: Int32
            let audio: Dimensions
            let text: Dimensions
            let mels: Int32
            let ftype: Int32
        }

        struct Parameters: Encodable {
            let model: String
            let language: String
            let translate: Bool
        }

        struct Result: Encodable {
            let language: String
        }

        struct Timings: Encodable {
            let from: String
            let to: String
        }

        struct Offsets: Encodable {
            let from: Int64
            let to: Int64
        }

        struct Segment: Encodable {
            let timestamps: Timings
            let offsets: Offsets
            let text: String
        }

        let systeminfo: String
        let model: Model
        let params: Parameters
        let result: Result
        let transcription: [Segment]
    }

    static func write(_ transcript: EiducoTranscript, to lessonDirectory: URL) throws {
        let segments = transcript.segments
        guard !segments.isEmpty else { throw EiducoWhisperError.missingOutput }

        let metadata = transcript.metadata
        let model = JSONDocument.Model(
            type: metadata.modelType,
            multilingual: metadata.multilingual,
            vocab: metadata.vocabularySize,
            audio: .init(ctx: metadata.audioContext, state: metadata.audioState, head: metadata.audioHeads, layer: metadata.audioLayers),
            text: .init(ctx: metadata.textContext, state: metadata.textState, head: metadata.textHeads, layer: metadata.textLayers),
            mels: metadata.melCount,
            ftype: metadata.modelTypeCode
        )
        let jsonSegments = segments.map { segment in
            JSONDocument.Segment(
                timestamps: .init(from: timestamp(segment.start, separator: "."), to: timestamp(segment.end, separator: ".")),
                offsets: .init(from: Int64((segment.start * 1_000).rounded()), to: Int64((segment.end * 1_000).rounded())),
                text: segment.text
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let json = try encoder.encode(JSONDocument(
            systeminfo: metadata.systemInfo,
            model: model,
            params: .init(model: metadata.modelPath, language: metadata.language, translate: false),
            result: .init(language: metadata.detectedLanguage),
            transcription: jsonSegments
        ))

        let outputs: [(String, Data)] = [
            ("trascrizione_raw.vtt", Data(makeVTT(segments).utf8)),
            ("trascrizione_raw.srt", Data(makeSRT(segments).utf8)),
            ("trascrizione_raw.json", json)
        ]

        for (name, data) in outputs {
            guard !data.isEmpty else { throw EiducoWhisperError.missingOutput }
            let destination = lessonDirectory.appendingPathComponent(name, isDirectory: false)
            try data.write(to: destination, options: .atomic)
        }
    }

    private static func makeVTT(_ segments: [EiducoTranscriptSegment]) -> String {
        var lines = ["WEBVTT", ""]
        for segment in segments {
            lines.append("\(timestamp(segment.start, separator: ".")) --> \(timestamp(segment.end, separator: "."))")
            lines.append(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func makeSRT(_ segments: [EiducoTranscriptSegment]) -> String {
        var lines: [String] = []
        for (index, segment) in segments.enumerated() {
            lines.append(String(index + 1))
            lines.append("\(timestamp(segment.start, separator: ",")) --> \(timestamp(segment.end, separator: ","))")
            lines.append(segment.text.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func timestamp(_ seconds: Double, separator: String) -> String {
        let milliseconds = max(0, Int((seconds * 1_000).rounded()))
        let hours = milliseconds / 3_600_000
        let minutes = (milliseconds % 3_600_000) / 60_000
        let wholeSeconds = (milliseconds % 60_000) / 1_000
        let remainder = milliseconds % 1_000
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, wholeSeconds, separator, remainder)
    }
}
