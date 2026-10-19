import Foundation
import AVFoundation
import CoreMedia

/// What Croc needs to know about a video before converting it, read with AVFoundation (no ffprobe needed).
struct VideoInfo {
    var duration: Double
    /// As shown, after rotation (phones store portrait videos as rotated landscape).
    var width: Int
    var height: Int
    var isHDR: Bool
    var hasAudio: Bool

    static func read(_ url: URL) async throws -> VideoInfo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw CrocError.noVideo
        }
        let (natural, transform, formats) = try await track.load(.naturalSize, .preferredTransform, .formatDescriptions)
        let shown = natural.applying(transform)
        let hdrCurves = [kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG, kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ]
        let isHDR = formats.contains { format in
            guard let curve = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_TransferFunction) else {
                return false
            }
            return hdrCurves.contains { CFEqual($0, curve) }
        }
        let audio = try await asset.loadTracks(withMediaType: .audio)
        return VideoInfo(duration: duration.isFinite ? duration : 0,
                         width: Int(abs(shown.width).rounded()), height: Int(abs(shown.height).rounded()),
                         isHDR: isHDR, hasAudio: !audio.isEmpty)
    }
}

enum CrocError: LocalizedError {
    case noVideo
    case noFFmpeg
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .noVideo: "This file has no video in it."
        case .noFFmpeg: "ffmpeg is missing from Croc.app. Build it again with build.sh."
        case .failed(let message): message
        }
    }
}

/// Runs the bundled ffmpeg for one video and reports progress from 0 to 1.
enum Encoder {
    static var ffmpeg: URL? {
        Bundle.main.url(forAuxiliaryExecutable: "ffmpeg")
    }

    static func run(_ arguments: [String], duration: Double, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard let ffmpeg else { throw CrocError.noFFmpeg }

        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice

        // -progress pipe:1 writes key=value lines; out_time_us is how far it got.
        let lines = LineBuffer()
        out.fileHandleForReading.readabilityHandler = { handle in
            for line in lines.append(handle.availableData) where line.hasPrefix("out_time_us=") {
                if let us = Double(line.dropFirst(12)), duration > 0 {
                    progress(min(1, max(0, us / 1_000_000 / duration)))
                }
            }
        }
        let errors = ErrorBuffer()
        err.fileHandleForReading.readabilityHandler = { handle in errors.append(handle.availableData) }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { process in
                    out.fileHandleForReading.readabilityHandler = nil
                    err.fileHandleForReading.readabilityHandler = nil
                    errors.append(err.fileHandleForReading.readDataToEndOfFile())
                    if process.terminationReason == .uncaughtSignal {
                        cont.resume(throwing: CancellationError())
                    } else if process.terminationStatus != 0 {
                        cont.resume(throwing: CrocError.failed(errors.summary))
                    } else {
                        cont.resume()
                    }
                }
                do {
                    try Task.checkCancellation()
                    try process.run()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}

/// Splits pipe output into lines; called from the pipe's reading thread only.
private final class LineBuffer: @unchecked Sendable {
    private var rest = ""

    func append(_ data: Data) -> [String] {
        rest += String(decoding: data, as: UTF8.self)
        var lines = rest.components(separatedBy: "\n")
        rest = lines.removeLast()
        return lines
    }
}

/// Keeps the end of ffmpeg's error output for the message shown when a conversion fails.
private final class ErrorBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    func append(_ data: Data) {
        lock.withLock { text = String((text + String(decoding: data, as: UTF8.self)).suffix(4000)) }
    }

    var summary: String {
        let last = lock.withLock { text }
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.last { !$0.isEmpty }
        return last.map { "ffmpeg: \($0)" } ?? "ffmpeg stopped with an error."
    }
}
