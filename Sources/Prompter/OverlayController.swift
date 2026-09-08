import AppKit

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // AppKit otherwise keeps windows below the menu bar, even after setFrame.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

final class OverlayController: NSWindowController, NSWindowDelegate {
    let scriptView = ScriptView(frame: .zero)
    private let playButton = NSButton()
    private let stateLabel = NSTextField(labelWithString: "Ready")
    private var movingProgrammatically = false
    var onPlay: (() -> Void)?
    var onReset: (() -> Void)?
    var onBack: (() -> Void)?
    var onEdit: (() -> Void)?
    var onHide: (() -> Void)?
    var onPositionChanged: ((NSRect) -> Void)?

    init(settings: PrompterSettings, savedFrame: NSRect?) {
        let screen = NSScreen.screens.first(where: { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }) ?? NSScreen.main ?? NSScreen.screens[0]
        let initial = savedFrame ?? NSRect(x: screen.frame.minX + 24, y: screen.frame.maxY - settings.height,
                                          width: settings.width, height: settings.height)
        let targetScreen = NSScreen.screens.max(by: {
            $0.frame.intersection(initial).area < $1.frame.intersection(initial).area
        }) ?? screen
        let frame = PanelGeometry.clamped(initial, to: targetScreen.frame)
        let panel = FloatingPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .black
        panel.isOpaque = true
        panel.hasShadow = true
        panel.animationBehavior = .none
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.title = "Prompter Overlay"
        super.init(window: panel)
        panel.delegate = self
        makeContent()
        scriptView.onDragEnded = { [weak self] in self?.finishDrag() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeContent() {
        guard let window else { return }
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.black.cgColor
        root.appearance = NSAppearance(named: .darkAqua)
        window.contentView = root

        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 4
        toolbar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        let handle = DragHandle(frame: .zero)
        handle.onDragEnded = { [weak self] in self?.finishDrag() }
        handle.widthAnchor.constraint(equalToConstant: 28).isActive = true
        handle.heightAnchor.constraint(equalToConstant: 30).isActive = true
        toolbar.addArrangedSubview(handle)
        configure(playButton, symbol: "play.fill", label: "Play (⌥⌘P)", action: #selector(play))
        toolbar.addArrangedSubview(playButton)
        toolbar.addArrangedSubview(button("arrow.counterclockwise", "Restart (⌥⌘R)", #selector(reset)))
        toolbar.addArrangedSubview(button("gobackward.5", "Back 5 seconds (⌥⌘J)", #selector(back)))
        stateLabel.font = .systemFont(ofSize: 11, weight: .medium)
        stateLabel.textColor = NSColor(white: 0.72, alpha: 1)
        stateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stateLabel.lineBreakMode = .byTruncatingTail
        toolbar.addArrangedSubview(stateLabel)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        toolbar.addArrangedSubview(spacer)
        toolbar.addArrangedSubview(button("arrow.up.to.line", "Snap to top, keeping horizontal position", #selector(snapToTop)))
        toolbar.addArrangedSubview(button("slider.horizontal.3", "Edit script and settings (⌘E)", #selector(edit)))
        toolbar.addArrangedSubview(button("xmark", "Hide overlay (⌥⌘O)", #selector(hide)))
        let rule = NSBox()
        rule.boxType = .separator
        for view in [scriptView, toolbar, rule] {
            view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(view)
        }
        NSLayoutConstraint.activate([
            scriptView.topAnchor.constraint(equalTo: root.topAnchor),
            scriptView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scriptView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scriptView.bottomAnchor.constraint(equalTo: rule.topAnchor),
            rule.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            rule.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            rule.heightAnchor.constraint(equalToConstant: 1),
            rule.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func configure(_ button: NSButton, symbol: String, label: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        button.contentTintColor = .white
        button.target = self
        button.action = action
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func button(_ symbol: String, _ label: String, _ action: Selector) -> NSButton {
        let result = NSButton()
        configure(result, symbol: symbol, label: label, action: action)
        return result
    }

    func updatePlayback(_ playback: Playback, hasText: Bool) {
        scriptView.offset = playback.offset
        let label = playback.isPlaying ? "Pause (⌥⌘P)" : "Play (⌥⌘P)"
        playButton.image = NSImage(systemSymbolName: playback.isPlaying ? "pause.fill" : "play.fill",
                                   accessibilityDescription: label)
        playButton.toolTip = label
        playButton.setAccessibilityLabel(label)
        playButton.isEnabled = hasText
        stateLabel.stringValue = !hasText ? "No script" : playback.isPlaying ? "Playing" : playback.reachedEnd ? "Finished" : playback.offset > 0 ? "Paused" : "Ready"
    }

    func applySize(_ settings: PrompterSettings) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        stateLabel.isHidden = settings.width < 360
        setFrame(PanelGeometry.resized(window.frame, size: NSSize(width: settings.width, height: settings.height),
                                       screen: screen.frame))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func setFrame(_ frame: NSRect) {
        movingProgrammatically = true
        window?.setFrame(frame, display: true)
        movingProgrammatically = false
        onPositionChanged?(frame)
    }

    func finishDrag() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let frame = PanelGeometry.clamped(window.frame, to: screen.frame)
        setFrame(abs(frame.maxY - screen.frame.maxY) < 18
                 ? PanelGeometry.snappedToTop(frame, screen: screen.frame) : frame)
    }

    func windowDidMove(_ notification: Notification) {
        if !movingProgrammatically, let window { onPositionChanged?(window.frame) }
    }

    @objc func snapToTop() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        setFrame(PanelGeometry.snappedToTop(window.frame, screen: screen.frame))
    }
    @objc private func play() { onPlay?() }
    @objc private func reset() { onReset?() }
    @objc private func back() { onBack?() }
    @objc private func edit() { onEdit?() }
    @objc private func hide() { onHide?() }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
