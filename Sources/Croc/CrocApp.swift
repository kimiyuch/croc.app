import SwiftUI
import AppKit

@main
struct CrocApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("Croc", id: "main") {
            ContentView()
                .environment(appDelegate.converter)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 920, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Videos…") { addVideos(to: appDelegate.converter) }
                    .keyboardShortcut("o")
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Convert") { appDelegate.converter.start() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(appDelegate.converter.isRunning || appDelegate.converter.waiting.isEmpty)
                Button("Stop") { appDelegate.converter.stop() }
                    .keyboardShortcut(".")
                    .disabled(!appDelegate.converter.isRunning)
                Button("Clear Finished") { appDelegate.converter.clearFinished() }
                    .keyboardShortcut("k")
                    .disabled(!appDelegate.converter.hasFinished)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let converter = Converter()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Videos dropped on the Dock icon or opened with "Open With → Croc".
    func application(_ application: NSApplication, open urls: [URL]) {
        converter.add(urls)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard converter.isRunning else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Stop converting and quit?"
        alert.informativeText = "The video Croc is working on won't be finished."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
        converter.stop()
        // Give ffmpeg a moment to stop and the half-written file to be removed.
        Task {
            for _ in 0..<20 where converter.isRunning {
                try? await Task.sleep(for: .milliseconds(100))
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@MainActor
func addVideos(to converter: Converter) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = true
    panel.allowedContentTypes = Converter.types
    panel.prompt = "Add"
    panel.message = "Choose videos, or a folder of videos"
    if panel.runModal() == .OK {
        converter.add(panel.urls)
    }
}

@MainActor
func chooseOutputFolder(for converter: Converter) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.prompt = "Save Here"
    panel.message = "Where should Croc put the converted videos?"
    if panel.runModal() == .OK, let url = panel.url {
        converter.outputFolder = url
    }
}
