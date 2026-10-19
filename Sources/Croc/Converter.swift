import Foundation
import Observation
import UniformTypeIdentifiers

/// One video in the list.
@Observable
final class Job: Identifiable {
    enum State: Equatable {
        case reading
        case waiting
        case converting(Double)
        case done(URL, Int64)
        case failed(String)
        case cancelled
    }

    let id = UUID()
    let input: URL
    let inputBytes: Int64
    var info: VideoInfo?
    var state: State = .reading
    /// What it was made with, so the row can say "WebM · 1080p" after you change the settings.
    var made: Settings?

    init(input: URL) {
        self.input = input
        inputBytes = (try? input.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    var name: String { input.lastPathComponent }

    var isActive: Bool {
        if case .converting = state { return true }
        return false
    }

    var isFinished: Bool {
        switch state {
        case .done, .failed, .cancelled: true
        default: false
        }
    }
}

/// The list of videos and the one-at-a-time conversion of it.
@MainActor
@Observable
final class Converter {
    private(set) var jobs: [Job] = []
    var settings: Settings {
        didSet { save() }
    }
    /// nil: next to each original.
    var outputFolder: URL? {
        didSet { UserDefaults.standard.set(outputFolder?.path, forKey: "outputFolder") }
    }

    private(set) var isRunning = false
    private var task: Task<Void, Never>?

    static let types: [UTType] = [.quickTimeMovie, .mpeg4Movie, .gif]

    init() {
        let defaults = UserDefaults.standard
        settings = Settings(
            format: OutputFormat(rawValue: defaults.string(forKey: "format") ?? "") ?? .mp4,
            maxSize: MaxSize(rawValue: defaults.object(forKey: "maxSize") as? Int ?? 1080) ?? .p1080,
            quality: Quality(rawValue: defaults.object(forKey: "quality") as? Int ?? 1) ?? .balanced)
        outputFolder = defaults.string(forKey: "outputFolder").map { URL(fileURLWithPath: $0) }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(settings.format.rawValue, forKey: "format")
        defaults.set(settings.maxSize.rawValue, forKey: "maxSize")
        defaults.set(settings.quality.rawValue, forKey: "quality")
    }

    var waiting: [Job] { jobs.filter { $0.state == .waiting } }
    var hasFinished: Bool { jobs.contains(where: \.isFinished) }
    var savedBytes: Int64 {
        jobs.reduce(0) { sum, job in
            if case .done(_, let bytes) = job.state { return sum + max(0, job.inputBytes - bytes) }
            return sum
        }
    }

    // MARK: - The list

    func add(_ urls: [URL]) {
        for url in urls {
            var isFolder: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) else { continue }
            if isFolder.boolValue {
                add(videos(in: url))
                continue
            }
            // Skip what's already in line.
            guard !jobs.contains(where: { $0.input == url && !$0.isFinished }),
                  Self.isVideo(url) else { continue }
            let job = Job(input: url)
            jobs.append(job)
            Task {
                do {
                    job.info = try await VideoInfo.read(url)
                    job.state = .waiting
                } catch {
                    job.state = .failed("Croc can't read this video: \(error.localizedDescription)")
                }
            }
        }
    }

    static func isVideo(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return types.contains { type.conforms(to: $0) }
    }

    private func videos(in folder: URL) -> [URL] {
        let items = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil,
                                                   options: [.skipsHiddenFiles, .skipsPackageDescendants])
        return (items?.allObjects as? [URL] ?? []).filter(Self.isVideo).sorted { $0.path < $1.path }
    }

    func remove(_ job: Job) {
        if job.isActive { return }
        jobs.removeAll { $0.id == job.id }
    }

    func clearFinished() {
        jobs.removeAll(where: \.isFinished)
    }

    /// Puts a finished, failed or cancelled video back in line, with the current settings.
    func retry(_ job: Job) {
        guard job.isFinished, job.info != nil else { return }
        job.state = .waiting
        job.made = nil
    }

    // MARK: - Converting

    func start() {
        guard !isRunning, !waiting.isEmpty else { return }
        isRunning = true
        task = Task {
            let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled],
                                                                 reason: "Converting videos")
            defer { ProcessInfo.processInfo.endActivity(activity) }
            while !Task.isCancelled, let job = waiting.first {
                await convert(job)
            }
            isRunning = false
            task = nil
        }
    }

    /// Stops the video being converted and everything after it.
    func stop() {
        task?.cancel()
    }

    private var current: Task<Void, Error>?

    /// Cancels one video: the running one stops, a waiting one is taken out of line.
    func cancel(_ job: Job) {
        if job.isActive {
            current?.cancel()
        } else if job.state == .waiting {
            job.state = .cancelled
        }
    }

    private func convert(_ job: Job) async {
        guard let info = job.info else { return }
        let settings = settings
        let output = outputURL(for: job.input, format: settings.format)
        // Write to a hidden file first, so a cancelled or failed run never leaves half a video behind.
        let partial = output.deletingLastPathComponent()
            .appendingPathComponent(".\(output.deletingPathExtension().lastPathComponent).croc-\(job.id.uuidString.prefix(8)).\(output.pathExtension)")
        let arguments = Command.arguments(input: job.input, output: partial, video: info, settings: settings)

        job.state = .converting(0)
        job.made = settings
        let run = Task {
            try await Encoder.run(arguments, duration: info.duration) { value in
                Task { @MainActor in
                    if job.isActive { job.state = .converting(value) }
                }
            }
        }
        current = run
        do {
            try await withTaskCancellationHandler {
                try await run.value
            } onCancel: {
                run.cancel()
            }
            try FileManager.default.moveItem(at: partial, to: output)
            let bytes = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            job.state = .done(output, bytes)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            // ffmpeg exits with an error code when it's stopped, so check whether it was asked to stop.
            job.state = error is CancellationError || run.isCancelled ? .cancelled : .failed(error.localizedDescription)
        }
        current = nil
    }

    /// clip.mov → clip.web.mp4, or "clip.web 2.mp4" if that exists already. Never overwrites anything.
    func outputURL(for input: URL, format: OutputFormat) -> URL {
        let folder = outputFolder ?? input.deletingLastPathComponent()
        let stem = input.deletingPathExtension().lastPathComponent + format.nameSuffix
        let ext = format.fileExtension
        var url = folder.appendingPathComponent(stem + "." + ext)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) || jobs.contains(where: { $0.outputPath == url }) {
            url = folder.appendingPathComponent("\(stem) \(n).\(ext)")
            n += 1
        }
        return url
    }
}

private extension Job {
    var outputPath: URL? {
        if case .done(let url, _) = state { return url }
        return nil
    }
}
