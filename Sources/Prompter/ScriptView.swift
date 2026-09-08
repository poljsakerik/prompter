import AppKit

/// TextKit lays the script out only when text, width, or font changes.
/// Playback redraws the visible glyphs, rather than rebuilding attributed text each frame.
final class ScriptView: NSView {
    private let storage = NSTextStorage()
    private let textLayout = NSLayoutManager()
    private let container = NSTextContainer()
    private var script = ""
    private var fontSize: CGFloat = 24
    private var laidOutWidth: CGFloat = 0
    private(set) var contentHeight: CGFloat = 0
    var offset: CGFloat = 0 { didSet { needsDisplay = true } }
    var onScroll: ((Double) -> Void)?
    var onReflow: ((Double, Double) -> Void)?
    var onDragEnded: (() -> Void)?
    override var isFlipped: Bool { true }
    var maximumOffset: Double { Double(max(0, contentHeight - bounds.height + 10)) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        storage.addLayoutManager(textLayout)
        textLayout.addTextContainer(container)
        container.lineFragmentPadding = 0
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Teleprompter script")
        setAccessibilityHelp("Drag to move the prompter. Scroll to move through the script and pause playback.")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(script: String, fontSize: CGFloat) {
        guard self.script != script || self.fontSize != fontSize else { return }
        let changedScript = self.script != script
        self.script = script
        self.fontSize = fontSize
        reflow(reset: changedScript)
        setAccessibilityValue(script.isEmpty ? "No script. Open Edit Script to get started." : script)
    }

    override func layout() {
        super.layout()
        if laidOutWidth != bounds.width { reflow(reset: false) }
    }

    private func reflow(reset: Bool) {
        // Keep the passage at the top in view when font size or width changes.
        var character: Int?
        if !reset, storage.length > 0, textLayout.numberOfGlyphs > 0 {
            let glyph = textLayout.glyphIndex(for: NSPoint(x: 0, y: max(0, offset - 10)), in: container)
            if glyph < textLayout.numberOfGlyphs { character = textLayout.characterIndexForGlyph(at: glyph) }
        }
        laidOutWidth = bounds.width
        container.containerSize = NSSize(width: max(1, bounds.width - 28), height: CGFloat.greatestFiniteMagnitude)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = fontSize * 0.22
        paragraph.paragraphSpacing = fontSize * 0.45
        paragraph.lineBreakMode = .byWordWrapping
        let displayText = script.isEmpty ? "Add your script to begin.\nOpen Edit Script below." : script
        storage.setAttributedString(NSAttributedString(string: displayText, attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]))
        textLayout.ensureLayout(for: container)
        contentHeight = textLayout.usedRect(for: container).height + 10
        var nextOffset: CGFloat = reset ? 0 : offset
        if let character, character < storage.length {
            let glyph = textLayout.glyphIndexForCharacter(at: character)
            nextOffset = textLayout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
        }
        offset = min(max(0, nextOffset), CGFloat(maximumOffset))
        onReflow?(Double(offset), maximumOffset)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
        NSGraphicsContext.saveGraphicsState()
        bounds.clip()
        let origin = NSPoint(x: 14, y: 10 - offset)
        let visible = NSRect(x: 0, y: max(0, offset - 10), width: container.containerSize.width,
                             height: bounds.height + fontSize * 2)
        let range = textLayout.glyphRange(forBoundingRect: visible, in: container)
        textLayout.drawBackground(forGlyphRange: range, at: origin)
        textLayout.drawGlyphs(forGlyphRange: range, at: origin)
        NSGraphicsContext.restoreGraphicsState()
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
        onDragEnded?()
    }

    override func scrollWheel(with event: NSEvent) {
        let multiplier: Double = event.hasPreciseScrollingDeltas ? 1 : 12
        onScroll?(-Double(event.scrollingDeltaY) * multiplier)
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}

final class DragHandle: NSView {
    var onDragEnded: (() -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        toolTip = "Drag to position the prompter"
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Drag handle. You can also drag the script area.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.55, alpha: 1).setFill()
        for y in [bounds.midY - 2, bounds.midY + 2] {
            NSBezierPath(roundedRect: NSRect(x: bounds.midX - 9, y: y, width: 18, height: 1),
                         xRadius: 0.5, yRadius: 0.5).fill()
        }
    }
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
        onDragEnded?()
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}
