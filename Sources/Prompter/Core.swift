import Foundation

struct PrompterSettings: Equatable {
    var width: Double = 600
    var height: Double = 190
    var fontSize: Double = 24
    /// Screen points per second, independent of the display's pixel density.
    var speed: Double = 35

    static let widthRange = 280.0...1000.0
    static let heightRange = 120.0...500.0
    static let fontRange = 14.0...64.0
    static let speedRange = 5.0...200.0

    mutating func validate() {
        width = Self.clamp(width, to: Self.widthRange, fallback: 600)
        height = Self.clamp(height, to: Self.heightRange, fallback: 190)
        fontSize = Self.clamp(fontSize, to: Self.fontRange, fallback: 24)
        // Always leave room for one full line above the 41-point transport strip.
        height = max(height, ceil(fontSize * 1.3) + 61)
        speed = Self.clamp(speed, to: Self.speedRange, fallback: 35)
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }

    init(defaults: UserDefaults? = nil) {
        guard let defaults else { return }
        if defaults.object(forKey: "width") != nil { width = defaults.double(forKey: "width") }
        if defaults.object(forKey: "height") != nil { height = defaults.double(forKey: "height") }
        if defaults.object(forKey: "fontSize") != nil { fontSize = defaults.double(forKey: "fontSize") }
        if defaults.object(forKey: "speed") != nil { speed = defaults.double(forKey: "speed") }
        validate()
    }

    func save(to defaults: UserDefaults) {
        defaults.set(width, forKey: "width")
        defaults.set(height, forKey: "height")
        defaults.set(fontSize, forKey: "fontSize")
        defaults.set(speed, forKey: "speed")
    }
}

struct Playback {
    private(set) var offset: Double = 0
    private(set) var isPlaying = false
    private(set) var reachedEnd = false

    mutating func toggle(hasText: Bool) {
        guard hasText else { return }
        if reachedEnd { offset = 0; reachedEnd = false }
        isPlaying.toggle()
    }

    mutating func pause() { isPlaying = false }

    mutating func reset() {
        offset = 0
        isPlaying = false
        reachedEnd = false
    }

    mutating func seek(to value: Double, maximum: Double) {
        offset = min(max(0, maximum), max(0, value))
        reachedEnd = false
    }

    mutating func advance(seconds: Double, speed: Double, maximum: Double) {
        guard isPlaying, seconds.isFinite, seconds > 0 else { return }
        offset = min(max(0, maximum), offset + seconds * speed)
        if offset >= max(0, maximum) {
            isPlaying = false
            reachedEnd = true
        }
    }
}

enum PanelGeometry {
    /// Uses the physical screen, not visibleFrame (which excludes the menu bar).
    static func clamped(_ rect: CGRect, to screen: CGRect) -> CGRect {
        let width = min(rect.width, screen.width)
        let height = min(rect.height, screen.height)
        return CGRect(
            x: min(max(rect.minX, screen.minX), screen.maxX - width),
            y: min(max(rect.minY, screen.minY), screen.maxY - height),
            width: width, height: height
        )
    }

    static func snappedToTop(_ rect: CGRect, screen: CGRect) -> CGRect {
        var result = clamped(rect, to: screen)
        result.origin.y = screen.maxY - result.height
        return result
    }

    static func resized(_ rect: CGRect, size: CGSize, screen: CGRect) -> CGRect {
        clamped(CGRect(x: rect.minX, y: rect.maxY - size.height,
                       width: size.width, height: size.height), to: screen)
    }
}
