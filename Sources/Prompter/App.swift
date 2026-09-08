import AppKit

@main
struct PrompterApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let smokeTest = CommandLine.arguments.contains("--smoke-test")
    private var defaults: UserDefaults!
    private var settings = PrompterSettings()
    private var script = ""
    private var playback = Playback()
    private var overlay: OverlayController!
    private var editor: EditorController!
    private var statusItem: NSStatusItem!
    private var hotkeys: Hotkeys?
    private var timer: Timer?
    private var saveTimer: Timer?
    private var lastTick: TimeInterval = 0
    private var localMonitor: Any?
    private var playMenuItems: [NSMenuItem] = []
    private var visibilityItem: NSMenuItem?
    private var hasText: Bool { !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private static let sample = """
    Welcome to Prompter.

    Drag this panel near your camera. Use Snap to top to bring the words right up to the screen’s edge.

    Read at your own pace. Adjust the width, text speed, and font size in Script & Settings until it feels comfortable.

    Press Option–Command–P to start or pause, even while another app is in front. Scroll with your mouse or trackpad to find your place.

    When you’re ready, replace this sample with your own script.
    """

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        defaults = smokeTest ? UserDefaults(suiteName: "local.prompter.smoke.\(UUID().uuidString)")! : .standard
        settings = PrompterSettings(defaults: defaults)
        script = defaults.string(forKey: "script") ?? Self.sample
        var frame: NSRect?
        if let saved = defaults.string(forKey: "overlayFrame") {
            let parsed = NSRectFromString(saved)
            if parsed.width > 0, parsed.height > 0,
               [parsed.origin.x, parsed.origin.y, parsed.width, parsed.height].allSatisfy(\.isFinite) {
                frame = parsed
            }
        }
        overlay = OverlayController(settings: settings, savedFrame: frame)
        editor = EditorController(script: script, settings: settings)
        connectActions()
        makeMenus()
        overlay.applySize(settings)
        overlay.scriptView.update(script: script, fontSize: settings.fontSize)
        overlay.window?.orderFrontRegardless()
        updateControls()
        if !smokeTest {
            hotkeys = Hotkeys()
            hotkeys?.onAction = { [weak self] id in self?.handleHotkey(id) }
            if let failures = hotkeys?.failedIDs, !failures.isEmpty {
                let item = NSMenuItem(title: "Some shortcuts are in use by another app", action: nil, keyEquivalent: "")
                statusItem.menu?.insertItem(item, at: 0)
                NSLog("Prompter: unable to register global shortcut IDs %@", failures.description)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.overlay.window else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 49, flags.intersection([.command, .option, .control]).isEmpty {
                self.togglePlayback(); return nil
            }
            if event.keyCode == 53 { self.hideOverlay(); return nil }
            return event
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(pauseForSleep),
                                                          name: NSWorkspace.willSleepNotification, object: nil)
        showEditor()
        if smokeTest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.runSmokeTest() }
        }
    }

    private func connectActions() {
        overlay.onPlay = { [weak self] in self?.togglePlayback() }
        overlay.onReset = { [weak self] in self?.reset() }
        overlay.onBack = { [weak self] in self?.back() }
        overlay.onEdit = { [weak self] in self?.showEditor() }
        overlay.onHide = { [weak self] in self?.hideOverlay() }
        overlay.onPositionChanged = { [weak self] frame in
            self?.defaults.set(NSStringFromRect(frame), forKey: "overlayFrame")
        }
        overlay.scriptView.onScroll = { [weak self] delta in
            guard let self else { return }
            self.playback.pause()
            self.stopTimer()
            self.playback.seek(to: self.playback.offset + delta, maximum: self.overlay.scriptView.maximumOffset)
            self.updateControls()
        }
        overlay.scriptView.onReflow = { [weak self] offset, maximum in
            guard let self else { return }
            self.playback.seek(to: offset, maximum: maximum)
            self.overlay.scriptView.offset = self.playback.offset
        }
        editor.onScriptChanged = { [weak self] text in
            guard let self else { return }
            self.script = text
            self.reset()
            self.overlay.scriptView.update(script: text, fontSize: self.settings.fontSize)
            self.scheduleSave()
        }
        editor.onSettingsChanged = { [weak self] settings in self?.applySettings(settings) }
        editor.onPlay = { [weak self] in self?.showOverlay(); self?.togglePlayback() }
        editor.onShow = { [weak self] in self?.showOverlay() }
        editor.onSnap = { [weak self] in self?.showOverlay(); self?.overlay.snapToTop() }
    }

    private func applySettings(_ newSettings: PrompterSettings) {
        let oldSettings = settings
        settings = newSettings
        settings.validate()
        if oldSettings.width != settings.width || oldSettings.height != settings.height {
            overlay.applySize(settings)
            playback.seek(to: playback.offset, maximum: overlay.scriptView.maximumOffset)
        }
        if oldSettings.fontSize != settings.fontSize {
            overlay.scriptView.update(script: script, fontSize: settings.fontSize)
        }
        editor.updateSettings(settings)
        updateControls()
        scheduleSave()
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in self?.save() }
    }

    private func save() {
        defaults.set(script, forKey: "script")
        settings.save(to: defaults)
    }

    @objc private func togglePlayback() {
        playback.toggle(hasText: hasText)
        if playback.isPlaying { showOverlay(); startTimer() } else { stopTimer() }
        updateControls()
    }

    private func startTimer() {
        stopTimer()
        lastTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 0.002
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = now - lastTick
        lastTick = now
        // Pause after a long stall rather than skipping words after sleep or a blocked run loop.
        if delta > 0.5 { playback.pause(); stopTimer(); updateControls(); return }
        playback.advance(seconds: delta, speed: settings.speed, maximum: overlay.scriptView.maximumOffset)
        overlay.scriptView.offset = playback.offset
        if !playback.isPlaying { stopTimer(); updateControls() }
    }

    @objc private func reset() { playback.reset(); stopTimer(); updateControls() }
    @objc private func back() {
        playback.seek(to: playback.offset - settings.speed * 5, maximum: overlay.scriptView.maximumOffset)
        updateControls()
    }
    @objc private func pauseForSleep() { playback.pause(); stopTimer(); updateControls() }

    private func updateControls() {
        overlay.updatePlayback(playback, hasText: hasText)
        editor.updatePlayback(playback, hasText: hasText)
        for item in playMenuItems { item.title = playback.isPlaying ? "Pause" : "Play"; item.isEnabled = hasText }
    }

    @objc private func showEditor() {
        NSApp.activate(ignoringOtherApps: true)
        editor.showWindow(nil)
        editor.window?.makeKeyAndOrderFront(nil)
    }
    @objc private func showOverlay() {
        overlay.window?.orderFrontRegardless()
        visibilityItem?.title = "Hide Overlay"
    }
    @objc private func hideOverlay() {
        playback.pause(); stopTimer(); updateControls()
        overlay.window?.orderOut(nil)
        visibilityItem?.title = "Show Overlay"
    }
    @objc private func toggleOverlay() {
        if overlay.window?.isVisible == true { hideOverlay() } else { showOverlay() }
    }
    @objc private func snap() { showOverlay(); overlay.snapToTop() }
    @objc private func screensChanged() { overlay.finishDrag() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func handleHotkey(_ id: UInt32) {
        switch id {
        case 1: togglePlayback()
        case 2: reset()
        case 3: back()
        case 4: toggleOverlay()
        case 5, 6:
            var next = settings
            next.speed += id == 5 ? 5 : -5
            applySettings(next)
        default: break
        }
    }

    private func makeMenus() {
        let main = NSMenu()
        let application = NSMenu()
        application.addItem(item("Script & Settings…", #selector(showEditor), key: "e"))
        application.addItem(.separator())
        application.addItem(item("Quit Prompter", #selector(quit), key: "q"))
        let appItem = NSMenuItem()
        appItem.submenu = application
        main.addItem(appItem)

        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", Selector(("undo:")), "z"),
                                     ("Redo", Selector(("redo:")), "Z"),
                                     ("Cut", #selector(NSText.cut(_:)), "x"),
                                     ("Copy", #selector(NSText.copy(_:)), "c"),
                                     ("Paste", #selector(NSText.paste(_:)), "v"),
                                     ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: key))
        }
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        main.addItem(editItem)
        let playbackMenu = makeTransportMenu()
        let playbackItem = NSMenuItem(title: "Playback", action: nil, keyEquivalent: "")
        playbackItem.submenu = playbackMenu
        main.addItem(playbackItem)
        NSApp.mainMenu = main

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Prompter")
        statusItem.button?.toolTip = "Prompter"
        let menu = makeTransportMenu()
        menu.insertItem(item("Script & Settings…", #selector(showEditor)), at: 0)
        menu.insertItem(.separator(), at: 1)
        menu.addItem(.separator())
        menu.addItem(item("Quit Prompter", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func makeTransportMenu() -> NSMenu {
        let menu = NSMenu(title: "Playback")
        menu.autoenablesItems = false
        let play = item("Play", #selector(togglePlayback), key: "p", modifiers: [.option, .command])
        playMenuItems.append(play)
        menu.addItem(play)
        menu.addItem(item("Restart", #selector(reset), key: "r", modifiers: [.option, .command]))
        menu.addItem(item("Back 5 Seconds", #selector(back), key: "j", modifiers: [.option, .command]))
        menu.addItem(.separator())
        menu.addItem(item("Snap to Top", #selector(snap)))
        let visibility = item("Show / Hide Overlay", #selector(toggleOverlay), key: "o", modifiers: [.option, .command])
        menu.addItem(visibility)
        visibilityItem = visibility
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showEditor(); showOverlay(); return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopTimer(); saveTimer?.invalidate(); save()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func runSmokeTest() {
        do {
            let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".impeccable/review")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            func capture(_ window: NSWindow?, name: String) throws {
                guard let view = window?.contentView else { throw SmokeError.capture }
                view.layoutSubtreeIfNeeded()
                view.displayIfNeeded()
                let destination = directory.appendingPathComponent(name + ".png")
                if CGPreflightScreenCaptureAccess(), let window {
                    // Capture the composited window: cacheDisplay does not reproduce macOS 26 glass controls.
                    window.display()
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    process.arguments = ["-x", "-o", "-l", String(window.windowNumber), destination.path]
                    try process.run()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else { throw SmokeError.capture }
                } else {
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw SmokeError.capture }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw SmokeError.capture }
                    try png.write(to: destination)
                    print("CAPTURE NOTE: view-only fallback; native glass controls may not render faithfully.")
                }
            }
            overlay.snapToTop()
            guard let window = overlay.window, let screen = window.screen,
                  abs(window.frame.maxY - screen.frame.maxY) < 1 else { throw SmokeError.geometry }
            try capture(editor.window, name: "workspace")
            try capture(overlay.window, name: "overlay-default")
            togglePlayback()
            playback.advance(seconds: 1, speed: settings.speed, maximum: overlay.scriptView.maximumOffset)
            guard playback.offset > 0 else { throw SmokeError.playback }
            hideOverlay()
            guard !playback.isPlaying, timer == nil else { throw SmokeError.playback }
            showOverlay()
            reset()
            var narrow = settings
            narrow.width = 280; narrow.fontSize = 64; narrow.height = 120
            applySettings(narrow)
            guard abs(window.frame.maxY - screen.frame.maxY) < 1 else { throw SmokeError.geometry }
            try capture(overlay.window, name: "overlay-narrow")
            editor.window?.setContentSize(NSSize(width: 720, height: 500))
            try capture(editor.window, name: "workspace-small")
            editor.window?.appearance = NSAppearance(named: .aqua)
            try capture(editor.window, name: "workspace-light")
            script = ""
            overlay.scriptView.update(script: script, fontSize: 24)
            reset()
            try capture(overlay.window, name: "overlay-empty")
            print("SMOKE PASS: physical top edge, resize anchor, playback, hide/pause, native window captures")
            NSApp.terminate(nil)
        } catch {
            fputs("SMOKE FAIL: \(error)\n", stderr)
            exit(1)
        }
    }

    private enum SmokeError: Error { case capture, geometry, playback }
}
