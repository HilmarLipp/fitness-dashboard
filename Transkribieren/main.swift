import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var progressBar: NSProgressIndicator!
    var statusLabel: NSTextField!
    var fileLabel: NSTextField!
    var percentLabel: NSTextField!
    var files: [URL] = []
    var outputDir: URL?
    var hasStarted = false
    var currentProcess: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        let args = CommandLine.arguments
        if args.count > 1 {
            files = Array(args.dropFirst()).compactMap { URL(fileURLWithPath: $0) }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.startIfReady()
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        files.append(contentsOf: filenames.compactMap { URL(fileURLWithPath: $0) })
        NSApp.reply(toOpenOrPrint: .success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.startIfReady()
        }
    }

    func startIfReady() {
        guard !hasStarted else { return }

        if files.isEmpty {
            selectFiles()
        } else {
            hasStarted = true
            selectOutputFolder()
        }
    }

    func setupAndShowWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Transkribieren"
        window.center()
        window.level = .floating
        window.isMovableByWindowBackground = true

        let contentView = NSView(frame: window.contentView!.bounds)
        window.contentView = contentView

        fileLabel = NSTextField(labelWithString: "")
        fileLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        fileLabel.frame = NSRect(x: 20, y: 100, width: 380, height: 20)
        fileLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(fileLabel)

        statusLabel = NSTextField(labelWithString: "Vorbereiten...")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.frame = NSRect(x: 20, y: 78, width: 320, height: 16)
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)

        percentLabel = NSTextField(labelWithString: "0%")
        percentLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        percentLabel.frame = NSRect(x: 360, y: 78, width: 40, height: 16)
        percentLabel.alignment = .right
        contentView.addSubview(percentLabel)

        progressBar = NSProgressIndicator(frame: NSRect(x: 20, y: 45, width: 380, height: 20))
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.doubleValue = 0
        contentView.addSubview(progressBar)

        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: 320, y: 10, width: 80, height: 24))
        cancelButton.title = "Abbrechen"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelTranscription)
        contentView.addSubview(cancelButton)

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @objc func cancelTranscription() {
        currentProcess?.terminate()
        NSApp.terminate(nil)
    }

    func selectFiles() {
        hasStarted = true
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3, .wav, .aiff]
        panel.message = "Audiodateien für Transkription auswählen"
        panel.prompt = "Auswählen"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK {
            self.files = panel.urls
            self.selectOutputFolder()
        } else {
            NSApp.terminate(nil)
        }
    }

    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Zielordner für Transkriptionen wählen"
        panel.prompt = "Auswählen"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")

        if panel.runModal() == .OK {
            let timestamp = currentTimestamp()
            let subfolderName = "Transkription_\(timestamp)"
            self.outputDir = panel.url!.appendingPathComponent(subfolderName)

            do {
                try FileManager.default.createDirectory(at: self.outputDir!, withIntermediateDirectories: true)
            } catch {
                showError("Ordner konnte nicht erstellt werden: \(error.localizedDescription)")
                return
            }

            setupAndShowWindow()
            startTranscription()
        } else {
            NSApp.terminate(nil)
        }
    }

    func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return formatter.string(from: Date())
    }

    func startTranscription() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.runTranscription()
        }
    }

    func updateUI(filename: String, phase: String, fileIndex: Int, total: Int, phaseProgress: Double) {
        DispatchQueue.main.async {
            let fileProgress = (Double(fileIndex) + phaseProgress) / Double(total) * 100
            self.fileLabel.stringValue = filename
            self.statusLabel.stringValue = phase
            self.progressBar.doubleValue = fileProgress
            self.percentLabel.stringValue = "\(Int(fileProgress))%"
            self.window.orderFrontRegardless()
        }
    }

    func runTranscription() {
        let total = files.count
        var success = 0
        var errors: [String] = []

        for (index, fileURL) in files.enumerated() {
            let filename = fileURL.lastPathComponent

            updateUI(filename: filename, phase: "Datei \(index + 1) von \(total) wird vorbereitet...", fileIndex: index, total: total, phaseProgress: 0.0)

            let process = Process()
            currentProcess = process

            // Use /bin/bash to ensure proper PATH
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [
                "-c",
                "python3 -m whisper \"\(fileURL.path)\" --model base --language German --output_dir \"\(outputDir!.path)\""
            ]

            var environment = ProcessInfo.processInfo.environment
            environment["LANG"] = "de_DE.UTF-8"
            environment["LC_ALL"] = "de_DE.UTF-8"
            environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:" + (environment["PATH"] ?? "")
            process.environment = environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()

                updateUI(filename: filename, phase: "Transkribiere...", fileIndex: index, total: total, phaseProgress: 0.1)

                // Poll while process is running
                var elapsed = 0.0
                while process.isRunning {
                    Thread.sleep(forTimeInterval: 0.5)
                    elapsed += 0.5
                    let estimatedProgress = min(0.1 + (elapsed / 180.0) * 0.8, 0.9)
                    updateUI(filename: filename, phase: "Transkribiere... (\(Int(elapsed))s)", fileIndex: index, total: total, phaseProgress: estimatedProgress)
                }

                // Wait for process to fully complete
                process.waitUntilExit()

                let status = process.terminationStatus

                if status == 0 {
                    success += 1
                    updateUI(filename: filename, phase: "Abgeschlossen ✓", fileIndex: index, total: total, phaseProgress: 1.0)
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unbekannter Fehler"
                    errors.append("\(filename): Exit \(status) - \(errorOutput.prefix(200))")
                    updateUI(filename: filename, phase: "Fehler ✗ (Code: \(status))", fileIndex: index, total: total, phaseProgress: 1.0)
                }

            } catch {
                errors.append("\(filename): \(error.localizedDescription)")
                updateUI(filename: filename, phase: "Fehler ✗", fileIndex: index, total: total, phaseProgress: 1.0)
            }

            Thread.sleep(forTimeInterval: 0.3)
        }

        currentProcess = nil

        DispatchQueue.main.async {
            self.progressBar.doubleValue = 100
            self.percentLabel.stringValue = "100%"
            self.statusLabel.stringValue = "Fertig!"
            self.fileLabel.stringValue = "\(success) von \(total) Dateien transkribiert"

            self.showNotification(success: success, total: total)

            // Show errors if any
            if !errors.isEmpty {
                let errorMsg = errors.joined(separator: "\n\n")
                self.showError("Einige Dateien konnten nicht transkribiert werden:\n\n\(errorMsg)")
            }

            if let outputDir = self.outputDir {
                NSWorkspace.shared.open(outputDir)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                NSApp.terminate(nil)
            }
        }
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Fehler"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    func showNotification(success: Int, total: Int) {
        let notification = NSUserNotification()
        notification.title = "Transkription fertig"
        notification.informativeText = "\(success) von \(total) Dateien transkribiert"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
