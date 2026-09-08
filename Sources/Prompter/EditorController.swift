import AppKit
import UniformTypeIdentifiers

final class EditorController: NSWindowController, NSTextViewDelegate {
    let textView = NSTextView()
    private let wordCount = NSTextField(labelWithString: "")
    private let playButton = NSButton(title: "Play", target: nil, action: nil)
    private var sliders: [String: NSSlider] = [:]
    private var values: [String: NSTextField] = [:]
    private var settings: PrompterSettings
    var onScriptChanged: ((String) -> Void)?
    var onSettingsChanged: ((PrompterSettings) -> Void)?
    var onPlay: (() -> Void)?
    var onShow: (() -> Void)?
    var onSnap: (() -> Void)?

    init(script: String, settings: PrompterSettings) {
        self.settings = settings
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Prompter — Script & Settings"
        window.minSize = NSSize(width: 720, height: 500)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("ScriptWorkspace")
        super.init(window: window)
        makeContent(script: script)
        if !window.setFrameUsingName("ScriptWorkspace") { window.center() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeContent(script: String) {
        guard let root = window?.contentView else { return }
        let editor = NSStackView()
        editor.orientation = .vertical
        editor.alignment = .leading
        editor.spacing = 14
        let header = NSStackView()
        header.orientation = .horizontal
        header.spacing = 8
        let heading = NSTextField(labelWithString: "Your script")
        heading.font = .systemFont(ofSize: 22, weight: .semibold)
        header.addArrangedSubview(heading)
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(makeButton("Import…", #selector(importScript)))
        header.addArrangedSubview(makeButton("Export…", #selector(exportScript)))
        editor.addArrangedSubview(header)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.autohidesScrollers = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 14, height: 16)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 450, height: CGFloat.greatestFiniteMagnitude)
        textView.string = script
        textView.delegate = self
        textView.setAccessibilityLabel("Script editor")
        scroll.documentView = textView
        editor.addArrangedSubview(scroll)
        let footer = NSStackView()
        footer.spacing = 8
        wordCount.font = .systemFont(ofSize: 11)
        wordCount.textColor = .secondaryLabelColor
        footer.addArrangedSubview(wordCount)
        footer.addArrangedSubview(NSView())
        let saved = NSTextField(labelWithString: "Saved automatically on this Mac")
        saved.font = .systemFont(ofSize: 11)
        saved.textColor = .secondaryLabelColor
        footer.addArrangedSubview(saved)
        editor.addArrangedSubview(footer)

        let separator = NSBox()
        separator.boxType = .separator
        let inspector = NSStackView()
        inspector.orientation = .vertical
        inspector.alignment = .leading
        inspector.spacing = 20
        let title = NSTextField(labelWithString: "Reading setup")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        inspector.addArrangedSubview(title)
        inspector.addArrangedSubview(setting("Width", key: "width", value: settings.width,
                                             range: PrompterSettings.widthRange, unit: "pt"))
        inspector.addArrangedSubview(setting("Text speed", key: "speed", value: settings.speed,
                                             range: PrompterSettings.speedRange, unit: "pt/s"))
        inspector.addArrangedSubview(setting("Font size", key: "fontSize", value: settings.fontSize,
                                             range: PrompterSettings.fontRange, unit: "pt"))
        inspector.addArrangedSubview(setting("Height", key: "height", value: settings.height,
                                             range: PrompterSettings.heightRange, unit: "pt"))
        let hint = NSTextField(wrappingLabelWithString: "Drag the script or its handle to place it near your camera. Snap to top removes the gap above it.")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        inspector.addArrangedSubview(hint)
        let placement = NSStackView()
        placement.spacing = 8
        placement.addArrangedSubview(makeButton("Show overlay", #selector(showOverlay)))
        placement.addArrangedSubview(makeButton("Snap to top", #selector(snap)))
        inspector.addArrangedSubview(placement)
        let shortcuts = NSTextField(wrappingLabelWithString: "⌥⌘P   Play / pause\n⌥⌘R   Restart\n⌥⌘J   Back 5 seconds\n⌥⌘O   Show / hide overlay")
        shortcuts.font = .systemFont(ofSize: 12)
        shortcuts.textColor = .secondaryLabelColor
        inspector.addArrangedSubview(shortcuts)
        let flexible = NSView()
        flexible.setContentHuggingPriority(.defaultLow, for: .vertical)
        inspector.addArrangedSubview(flexible)
        playButton.target = self
        playButton.action = #selector(play)
        playButton.bezelStyle = .rounded
        playButton.controlSize = .large
        playButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        playButton.imagePosition = .imageLeading
        inspector.addArrangedSubview(playButton)

        for view in [editor, separator, inspector] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }
        NSLayoutConstraint.activate([
            editor.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            editor.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            editor.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            editor.trailingAnchor.constraint(equalTo: separator.leadingAnchor, constant: -24),
            header.widthAnchor.constraint(equalTo: editor.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: editor.widthAnchor),
            footer.widthAnchor.constraint(equalTo: editor.widthAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.topAnchor.constraint(equalTo: root.topAnchor),
            separator.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            inspector.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 24),
            inspector.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            inspector.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            inspector.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            inspector.widthAnchor.constraint(equalToConstant: 248),
            hint.widthAnchor.constraint(equalTo: inspector.widthAnchor),
            shortcuts.widthAnchor.constraint(equalTo: inspector.widthAnchor),
            playButton.widthAnchor.constraint(equalTo: inspector.widthAnchor)
        ])
        updateWordCount()
    }

    private func setting(_ title: String, key: String, value: Double, range: ClosedRange<Double>, unit: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        let row = NSStackView()
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        let number = NSTextField(labelWithString: "\(Int(value)) \(unit)")
        number.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        number.textColor = .secondaryLabelColor
        row.addArrangedSubview(label)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(number)
        let slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound,
                              target: self, action: #selector(sliderChanged(_:)))
        slider.identifier = NSUserInterfaceItemIdentifier(key)
        slider.isContinuous = true
        slider.setAccessibilityLabel(title)
        slider.setAccessibilityHelp("\(Int(range.lowerBound)) to \(Int(range.upperBound)) \(unit)")
        stack.addArrangedSubview(row)
        stack.addArrangedSubview(slider)
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 248),
            row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            slider.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        sliders[key] = slider
        values[key] = number
        return stack
    }

    private func makeButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        guard let key = sender.identifier?.rawValue else { return }
        let value = sender.doubleValue.rounded()
        sender.doubleValue = value
        switch key {
        case "width": settings.width = value
        case "speed": settings.speed = value
        case "fontSize": settings.fontSize = value
        case "height": settings.height = value
        default: return
        }
        values[key]?.stringValue = "\(Int(value)) \(key == "speed" ? "pt/s" : "pt")"
        onSettingsChanged?(settings)
    }

    func updateSettings(_ settings: PrompterSettings) {
        self.settings = settings
        for (key, value) in [("width", settings.width), ("height", settings.height),
                             ("speed", settings.speed), ("fontSize", settings.fontSize)] {
            sliders[key]?.doubleValue = value
            values[key]?.stringValue = "\(Int(value)) \(key == "speed" ? "pt/s" : "pt")"
        }
    }

    func updatePlayback(_ playback: Playback, hasText: Bool) {
        playButton.title = playback.isPlaying ? "Pause" : playback.reachedEnd ? "Play again" : "Play"
        playButton.image = NSImage(systemSymbolName: playback.isPlaying ? "pause.fill" : "play.fill", accessibilityDescription: nil)
        playButton.isEnabled = hasText
    }

    func textDidChange(_ notification: Notification) {
        updateWordCount()
        onScriptChanged?(textView.string)
    }

    private func updateWordCount() {
        let count = textView.string.split(whereSeparator: \.isWhitespace).count
        wordCount.stringValue = "\(count.formatted()) \(count == 1 ? "word" : "words")"
    }

    @objc private func importScript() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self, let url = panel.url else { return }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 5_000_000 else {
                    throw NSError(domain: "Prompter", code: 1, userInfo: [NSLocalizedDescriptionKey: "This file is too large. Choose a plain-text script smaller than 5 MB."])
                }
                var encoding = String.Encoding.utf8
                let text = try String(contentsOf: url, usedEncoding: &encoding)
                // Insert through the editor so importing can be undone with Command-Z.
                let range = NSRange(location: 0, length: (self.textView.string as NSString).length)
                if self.textView.shouldChangeText(in: range, replacementString: text) {
                    self.textView.textStorage?.replaceCharacters(in: range, with: text)
                    self.textView.didChangeText()
                    self.textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                }
            } catch { self.showError(error, title: "Couldn’t import script") }
        }
    }

    @objc private func exportScript() {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Script.txt"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self, let url = panel.url else { return }
            do { try self.textView.string.write(to: url, atomically: true, encoding: .utf8) }
            catch { self.showError(error, title: "Couldn’t export script") }
        }
    }

    private func showError(_ error: Error, title: String) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.beginSheetModal(for: window)
    }

    @objc private func play() { onPlay?() }
    @objc private func showOverlay() { onShow?() }
    @objc private func snap() { onSnap?() }
}
