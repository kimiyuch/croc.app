import Foundation

/// What comes out: the three web formats Croc makes.
enum OutputFormat: String, CaseIterable, Identifiable {
    case mp4, webm, loop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mp4: "Web MP4"
        case .webm: "WebM"
        case .loop: "Silent loop"
        }
    }

    var detail: String {
        switch self {
        case .mp4: "H.264 and AAC. Plays in every browser, starts before it has fully loaded."
        case .webm: "VP9 and Opus. Smaller files, takes longer to make."
        case .loop: "H.264 without sound, for background and hero videos."
        }
    }

    var symbol: String {
        switch self {
        case .mp4: "play.rectangle"
        case .webm: "leaf"
        case .loop: "repeat"
        }
    }

    /// Added to the original name: clip.mov becomes clip.web.mp4, clip.webm or clip.loop.mp4.
    var nameSuffix: String {
        switch self {
        case .mp4: ".web"
        case .webm: ""
        case .loop: ".loop"
        }
    }

    var fileExtension: String {
        self == .webm ? "webm" : "mp4"
    }
}

/// The largest size the video may have. Applies to the short side, so portrait videos are treated the same.
enum MaxSize: Int, CaseIterable, Identifiable {
    case p720 = 720, p1080 = 1080, p1440 = 1440, original = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .p720: "720p"
        case .p1080: "1080p"
        case .p1440: "1440p"
        case .original: "Original"
        }
    }
}

enum Quality: Int, CaseIterable, Identifiable {
    case smaller, balanced, better

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .smaller: "Smaller"
        case .balanced: "Balanced"
        case .better: "Better"
        }
    }

    /// Constant rate factor: lower is better and bigger. x264 and VP9 use different scales.
    var x264CRF: Int { [26, 23, 20][rawValue] }
    var vp9CRF: Int { [36, 32, 28][rawValue] }
}

struct Settings: Equatable {
    var format: OutputFormat = .mp4
    var maxSize: MaxSize = .p1080
    var quality: Quality = .balanced
}

/// The ffmpeg command line for one video.
enum Command {
    /// The output size: fits within maxSize on the short side and the matching 16:9 length on the long side,
    /// never upscales, and both sides even (H.264 with 4:2:0 needs that).
    static func size(width: Int, height: Int, max: MaxSize) -> (width: Int, height: Int) {
        guard width > 0, height > 0 else { return (width, height) }
        var scale = 1.0
        if max != .original {
            let short = Double(min(width, height)), long = Double(Swift.max(width, height))
            scale = min(1, Double(max.rawValue) / short, Double(max.rawValue) * 16 / 9 / long)
        }
        func even(_ value: Double) -> Int { Swift.max(2, Int((value / 2).rounded()) * 2) }
        return (even(Double(width) * scale), even(Double(height) * scale))
    }

    static func arguments(input: URL, output: URL, video: VideoInfo, settings: Settings) -> [String] {
        let target = size(width: video.width, height: video.height, max: settings.maxSize)

        // iPhone footage is often HDR (HLG or PQ); turn it into normal SDR so it doesn't look grey in the browser.
        var filters: [String] = []
        if video.isHDR {
            filters.append("zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv")
        }
        filters.append("scale=\(target.width):\(target.height):flags=lanczos")
        // Tag the frames as normal HD video; ffmpeg takes the colour tags from the frames, not from -color_trc.
        filters.append("format=yuv420p,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv")

        var args = ["-hide_banner", "-nostdin", "-nostats", "-loglevel", "error", "-progress", "pipe:1",
                    "-i", input.path,
                    "-map", "0:v:0", "-vf", filters.joined(separator: ","),
                    "-map_metadata", "-1", "-map_chapters", "-1"]

        switch settings.format {
        case .mp4, .loop:
            args += ["-c:v", "libx264", "-preset", "slow", "-crf", "\(settings.quality.x264CRF)", "-profile:v", "high"]
            if settings.format == .mp4 {
                args += ["-map", "0:a:0?", "-c:a", "aac", "-b:a", "128k", "-ac", "2"]
            } else {
                args += ["-an"]
            }
            args += ["-movflags", "+faststart", "-f", "mp4"]
        case .webm:
            args += ["-c:v", "libvpx-vp9", "-crf", "\(settings.quality.vp9CRF)", "-b:v", "0",
                     "-row-mt", "1", "-deadline", "good", "-cpu-used", "2",
                     "-map", "0:a:0?", "-c:a", "libopus", "-b:a", "96k", "-ac", "2",
                     "-f", "webm"]
        }
        return args + ["-y", output.path]
    }
}
