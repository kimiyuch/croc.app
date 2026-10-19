import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(Converter.self) private var converter
    @State private var dropping = false

    var body: some View {
        VStack(spacing: 0) {
            Hero()
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    SettingsSection()
                    if converter.jobs.isEmpty {
                        DropZone(highlighted: dropping)
                    } else {
                        JobList()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 36)
            }
        }
        .ignoresSafeArea(edges: .top)
        .frame(minWidth: 760, minHeight: 620)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.accent)
        .overlay {
            if dropping && !converter.jobs.isEmpty {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Billabong.c500, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { Task { @MainActor in converter.add([url]) } }
                }
            }
            return true
        }
    }
}

// MARK: - Hero

/// The band at the top: the app, what's in line and the main button. Light green in light mode, dark in dark mode.
struct Hero: View {
    @Environment(Converter.self) private var converter

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Croc").font(.display(19)).foregroundStyle(Hero.title)
                Text(summary).font(.callout).foregroundStyle(Hero.subtitle).monospacedDigit()
            }
            Spacer()
            if converter.isRunning {
                Button { converter.stop() } label: { Label("Stop", systemImage: "stop.fill") }
                    .buttonStyle(PillButtonStyle(surface: Hero.button, large: true))
            } else {
                Button { addVideos(to: converter) } label: { Label("Add videos", systemImage: "plus") }
                    .buttonStyle(PillButtonStyle(surface: Hero.button, large: true))
                Button { converter.start() } label: {
                    Label(convertTitle, systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .buttonStyle(PillButtonStyle(prominent: true, tint: Hero.convert, foreground: Hero.convertText, large: true))
                .disabled(converter.waiting.isEmpty)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .padding(.bottom, 22)
        .background(LinearGradient(colors: [Hero.top, Hero.bottom], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .bottom) { Rectangle().fill(Hero.border).frame(height: 1) }
    }

    private static let top = Color.adaptive(light: Billabong.c100, dark: Billabong.c900)
    private static let bottom = Color.adaptive(light: Billabong.c200, dark: Billabong.c950)
    private static let border = Color.adaptive(light: Billabong.c950.opacity(0.1), dark: .white.opacity(0.08))
    private static let title = Color.adaptive(light: Billabong.c950, dark: .white)
    private static let subtitle = Color.adaptive(light: Billabong.c900.opacity(0.7), dark: Billabong.c100.opacity(0.7))
    private static let button = Color.adaptive(light: .white.opacity(0.6), dark: .white.opacity(0.05))
    // On the light band a white button looks too much like the others, so the main one is filled green there.
    private static let convert = Color.adaptive(light: Billabong.c600, dark: .white)
    private static let convertText = Color.adaptive(light: .white, dark: Billabong.c950)

    private var convertTitle: String {
        let count = converter.waiting.count
        return count > 1 ? "Convert \(count) videos" : "Convert"
    }

    private var summary: String {
        let done = converter.jobs.filter { if case .done = $0.state { true } else { false } }.count
        if converter.jobs.isEmpty { return "Chews big videos down to size" }
        var parts = ["\(converter.jobs.count) \(converter.jobs.count == 1 ? "video" : "videos")"]
        if done > 0 { parts.append("\(done) done") }
        if converter.savedBytes > 0 { parts.append("\(fmt(converter.savedBytes)) saved") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Settings

struct SettingsSection: View {
    @Environment(Converter.self) private var converter

    var body: some View {
        @Bindable var converter = converter
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(OutputFormat.allCases) { format in
                    FormatCard(format: format, selected: converter.settings.format == format) {
                        converter.settings.format = format
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            // One row when the window is wide enough, otherwise "Save to" moves to a second line.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 28) {
                    pickers
                    Spacer(minLength: 0)
                    saveTo
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 28) { pickers }
                    saveTo
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .disabled(converter.isRunning)
    }

    @ViewBuilder
    private var pickers: some View {
        @Bindable var converter = converter
        Labeled("Size") {
            Picker("Size", selection: $converter.settings.maxSize) {
                ForEach(MaxSize.allCases) { Text($0.title).tag($0) }
            }
            .fixedSize()
        }
        Labeled("Quality") {
            Picker("Quality", selection: $converter.settings.quality) {
                ForEach(Quality.allCases) { Text($0.title).tag($0) }
            }
            .fixedSize()
        }
    }

    private var saveTo: some View {
        Labeled("Save to") {
            Menu {
                Button("Next to the originals") { converter.outputFolder = nil }
                Button("Choose a folder…") { chooseOutputFolder(for: converter) }
                if let folder = converter.outputFolder {
                    Divider()
                    Button("Show \(folder.lastPathComponent) in Finder") { reveal(folder) }
                }
            } label: {
                Label(converter.outputFolder?.lastPathComponent ?? "Next to the originals",
                      systemImage: converter.outputFolder == nil ? "doc.on.doc" : "folder")
            }
            .fixedSize()
            .help(converter.outputFolder?.path ?? "Each video is saved in the folder of its original")
        }
    }
}

private struct Labeled<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted).fixedSize()
            content
        }
    }
}

private struct FormatCard: View {
    let format: OutputFormat
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: format.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? .white : Theme.accent)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Billabong.c600 : Theme.pageTop))
                VStack(alignment: .leading, spacing: 3) {
                    Text(format.title).font(.display(15)).foregroundStyle(Theme.ink)
                    Text(format.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(selected ? Billabong.c500 : Theme.ring, lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drop zone

struct DropZone: View {
    @Environment(Converter.self) private var converter
    let highlighted: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "film.stack")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Theme.pageTop))
            Text("Drop videos here")
                .font(.display(26))
                .tracking(-0.5)
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)
            Text("MOV and MP4 from your phone, camera or screen recordings, and animated GIFs. Croc makes small copies for the web and leaves the originals alone.")
                .font(.system(size: 14))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: 440)
                .padding(.top, 8)
            Button { addVideos(to: converter) } label: { Label("Choose videos", systemImage: "plus") }
                .buttonStyle(.pillProminent)
                .padding(.top, 20)
            Text("Nothing leaves your Mac · Croc never connects to the internet")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .padding(.top, 22)
        }
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(highlighted ? Billabong.c500.opacity(0.08) : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(highlighted ? Billabong.c500 : Theme.ring,
                          style: StrokeStyle(lineWidth: highlighted ? 2 : 1.5, dash: [8, 5])))
    }
}

// MARK: - The list

struct JobList: View {
    @Environment(Converter.self) private var converter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Videos").font(.display(15)).foregroundStyle(Theme.ink)
                Spacer()
                if converter.hasFinished {
                    Button("Clear finished") { converter.clearFinished() }.buttonStyle(.pill)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(converter.jobs.enumerated()), id: \.element.id) { index, job in
                    if index > 0 { Rectangle().fill(Theme.divider).frame(height: 1) }
                    JobRow(job: job)
                }
            }
            .cardSurface(padding: 0)
            Text("Drop more videos anywhere in the window.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }
}

struct JobRow: View {
    @Environment(Converter.self) private var converter
    let job: Job
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            ItemIcon(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(job.name)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(isFailure ? Theme.red : Theme.muted)
                    .lineLimit(2)
                    .monospacedDigit()
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) {
            if case .done(let url, _) = job.state { reveal(url) }
        }
        .contextMenu {
            if case .done(let url, _) = job.state {
                Button("Show in Finder") { reveal(url) }
                Button("Open") { NSWorkspace.shared.open(url) }
            }
            Button("Show Original in Finder") { reveal(job.input) }
            if job.isFinished && job.info != nil {
                Button("Convert Again") { converter.retry(job) }
            }
            if !job.isActive {
                Divider()
                Button("Remove from List") { converter.remove(job) }
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch job.state {
        case .reading:
            ProgressView().controlSize(.small)
        case .waiting:
            Text("Waiting").font(.callout).foregroundStyle(Theme.muted)
            removeButton
        case .converting(let value):
            ProgressView(value: value)
                .progressViewStyle(.linear)
                .tint(Billabong.c500)
                .frame(width: 140)
            Text("\(Int(value * 100))%")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .frame(width: 38, alignment: .trailing)
            IconButton(symbol: "xmark.circle.fill", help: "Stop this video") { converter.cancel(job) }
        case .done(let url, let bytes):
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(fmt(job.inputBytes)) → \(fmt(bytes))")
                    .font(.callout).monospacedDigit().foregroundStyle(Theme.text)
                if job.inputBytes > 0 {
                    Text(change(bytes))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(bytes < job.inputBytes ? Theme.green : Theme.orange)
                }
            }
            IconButton(symbol: "magnifyingglass.circle.fill", help: "Show in Finder") { reveal(url) }
        case .failed, .cancelled:
            if job.info != nil {
                IconButton(symbol: "arrow.clockwise.circle.fill", help: "Try again") { converter.retry(job) }
            }
            removeButton
        }
    }

    private var removeButton: some View {
        IconButton(symbol: "minus.circle.fill", help: "Remove from the list") { converter.remove(job) }
            .opacity(hovering ? 1 : 0.5)
    }

    private var isFailure: Bool {
        if case .failed = job.state { return true }
        return false
    }

    private var symbol: String {
        switch job.state {
        case .done: "checkmark"
        case .failed: "exclamationmark.triangle"
        case .cancelled: "xmark"
        default: "film"
        }
    }

    private var tint: Color {
        switch job.state {
        case .done: Theme.green
        case .failed: Theme.red
        case .cancelled: Theme.muted
        default: Theme.accent
        }
    }

    private var detail: String {
        switch job.state {
        case .failed(let message): return message
        case .cancelled: return "Stopped"
        case .done(let url, _):
            let made = job.made.map { " · \($0.format.title)" } ?? ""
            return url.lastPathComponent + made
        default:
            guard let info = job.info else { return fmt(job.inputBytes) }
            var parts = ["\(info.width)×\(info.height)", clock(info.duration), fmt(job.inputBytes)]
            if info.isHDR { parts.append("HDR") }
            if !info.hasAudio { parts.append("no sound") }
            if job.state == .waiting {
                let target = Command.size(width: info.width, height: info.height, max: converter.settings.maxSize)
                if target.width != info.width || target.height != info.height {
                    parts.append("→ \(target.width)×\(target.height)")
                }
            }
            return parts.joined(separator: " · ")
        }
    }

    private func change(_ bytes: Int64) -> String {
        let ratio = Double(bytes) / Double(job.inputBytes)
        if ratio < 1 { return "\(Int(((1 - ratio) * 100).rounded()))% smaller" }
        return "\(Int(((ratio - 1) * 100).rounded()))% bigger"
    }
}

// MARK: - Building blocks

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(Theme.muted)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// An SF Symbol on a soft tinted square, in front of list rows.
struct ItemIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 7).fill(tint.opacity(0.12)))
    }
}

private let byteFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.countStyle = .file
    f.allowedUnits = [.useGB, .useMB, .useKB]
    return f
}()

func fmt(_ bytes: Int64) -> String {
    byteFormatter.string(fromByteCount: bytes)
}

/// 0:06, 4:32, 1:02:03
func clock(_ seconds: Double) -> String {
    let s = Int(seconds.rounded())
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}

func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
}
