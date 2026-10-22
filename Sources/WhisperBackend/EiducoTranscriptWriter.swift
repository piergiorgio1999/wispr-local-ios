import Foundation

enum EiducoTranscriptWriter {
    private struct JSONDocument: Encodable {
        let text: String
        let segments: [EiducoTranscriptSegment]
    }

    static func write(_ segments: [EiducoTranscriptSegment], to lessonDirectory: URL) throws {
        guard !segments.isEmpty else { throw EiducoWhisperError.missingOutput }

        let transcript = segments.map(\.text).joined()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let json = try encoder.encode(JSONDocument(text: transcript, segments: segments))

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
