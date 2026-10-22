import AVFoundation
import CoreMedia
import Foundation

enum EiducoAudioDecoder {
    static func decodeMono16kFloat(from url: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            throw EiducoWhisperError.noAudioTrack(url)
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw EiducoWhisperError.audioDecodeFailed("formato PCM mono non supportato")
        }
        reader.add(output)

        guard reader.startReading() else {
            throw EiducoWhisperError.audioDecodeFailed(reader.error?.localizedDescription ?? "avvio del decoder fallito")
        }

        var samples: [Float] = []
        while let sampleBuffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            var lengthAtOffset = 0
            var totalLength = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            let status = CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: &totalLength,
                dataPointerOut: &dataPointer
            )
            guard status == kCMBlockBufferNoErr, let dataPointer else {
                throw EiducoWhisperError.audioDecodeFailed("lettura del buffer PCM fallita")
            }

            let sampleCount = totalLength / MemoryLayout<Float>.size
            let floatPointer = UnsafeRawPointer(dataPointer).assumingMemoryBound(to: Float.self)
            samples.append(contentsOf: UnsafeBufferPointer(start: floatPointer, count: sampleCount))
        }

        guard reader.status == .completed, !samples.isEmpty else {
            throw EiducoWhisperError.audioDecodeFailed(reader.error?.localizedDescription ?? "nessun campione audio")
        }
        return samples
    }
}
