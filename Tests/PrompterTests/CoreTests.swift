import XCTest
@testable import Prompter

final class CoreTests: XCTestCase {
    func testDefaultsMatchCompactReferenceWidth() {
        let settings = PrompterSettings()
        XCTAssertEqual(settings.width, 600)
        XCTAssertEqual(settings.fontSize, 24)
    }

    func testSettingsRejectInvalidStoredValues() {
        var settings = PrompterSettings()
        settings.width = .nan
        settings.height = -1
        settings.fontSize = .infinity
        settings.speed = 500
        settings.validate()
        XCTAssertEqual(settings.width, 600)
        XCTAssertEqual(settings.height, 120)
        XCTAssertEqual(settings.fontSize, 24)
        XCTAssertEqual(settings.speed, 200)
    }

    func testLargeFontAlwaysHasRoomForOneLine() {
        var settings = PrompterSettings()
        settings.height = 120
        settings.fontSize = 64
        settings.validate()
        XCTAssertGreaterThanOrEqual(settings.height, 145)
    }

    func testSettingsRoundTrip() throws {
        let name = "PrompterTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var settings = PrompterSettings()
        settings.width = 480; settings.height = 250; settings.fontSize = 32; settings.speed = 65
        settings.save(to: defaults)
        XCTAssertEqual(PrompterSettings(defaults: defaults), settings)
    }

    func testScrollingUsesElapsedTime() {
        var playback = Playback()
        playback.toggle(hasText: true)
        playback.advance(seconds: 0.5, speed: 40, maximum: 100)
        XCTAssertEqual(playback.offset, 20)
        playback.advance(seconds: 0.25, speed: 40, maximum: 100)
        XCTAssertEqual(playback.offset, 30)
        XCTAssertTrue(playback.isPlaying)
    }

    func testPauseDoesNotScroll() {
        var playback = Playback()
        playback.toggle(hasText: true)
        playback.advance(seconds: 1, speed: 20, maximum: 100)
        playback.pause()
        playback.advance(seconds: 1, speed: 20, maximum: 100)
        XCTAssertEqual(playback.offset, 20)
    }

    func testEndStopsAndPlayRestarts() {
        var playback = Playback()
        playback.toggle(hasText: true)
        playback.advance(seconds: 20, speed: 20, maximum: 100)
        XCTAssertEqual(playback.offset, 100)
        XCTAssertFalse(playback.isPlaying)
        XCTAssertTrue(playback.reachedEnd)
        playback.toggle(hasText: true)
        XCTAssertTrue(playback.isPlaying)
        XCTAssertFalse(playback.reachedEnd)
        XCTAssertEqual(playback.offset, 0)
    }

    func testEmptyScriptCannotPlay() {
        var playback = Playback()
        playback.toggle(hasText: false)
        XCTAssertFalse(playback.isPlaying)
    }

    func testShortScriptStopsWithoutNegativeOffset() {
        var playback = Playback()
        playback.toggle(hasText: true)
        playback.advance(seconds: 1, speed: 40, maximum: -20)
        XCTAssertEqual(playback.offset, 0)
        XCTAssertFalse(playback.isPlaying)
    }

    func testSeekAndReset() {
        var playback = Playback()
        playback.seek(to: -100, maximum: 200)
        XCTAssertEqual(playback.offset, 0)
        playback.seek(to: 400, maximum: 200)
        XCTAssertEqual(playback.offset, 200)
        playback.toggle(hasText: true)
        playback.reset()
        XCTAssertEqual(playback.offset, 0)
        XCTAssertFalse(playback.isPlaying)
        XCTAssertFalse(playback.reachedEnd)
    }

    func testInvalidElapsedTimeIgnored() {
        var playback = Playback()
        playback.toggle(hasText: true)
        playback.advance(seconds: .nan, speed: 40, maximum: 200)
        playback.advance(seconds: -1, speed: 40, maximum: 200)
        XCTAssertEqual(playback.offset, 0)
    }

    func testSnapUsesPhysicalTopAndPreservesHorizontalPosition() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = CGRect(x: 140, y: 300, width: 600, height: 190)
        let snapped = PanelGeometry.snappedToTop(frame, screen: screen)
        XCTAssertEqual(snapped.maxY, screen.maxY)
        XCTAssertEqual(snapped.minX, 140)
    }

    func testResizePreservesTopEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = CGRect(x: 80, y: 792, width: 600, height: 190)
        let resized = PanelGeometry.resized(frame, size: CGSize(width: 400, height: 350), screen: screen)
        XCTAssertEqual(resized.maxY, frame.maxY)
        XCTAssertEqual(resized.minX, frame.minX)
        XCTAssertEqual(resized.size, CGSize(width: 400, height: 350))
    }

    func testClampRecoversDisconnectedMonitorPosition() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = CGRect(x: -2000, y: 1500, width: 600, height: 190)
        let clamped = PanelGeometry.clamped(frame, to: screen)
        XCTAssertTrue(screen.contains(clamped))
        XCTAssertEqual(clamped.minX, 0)
        XCTAssertEqual(clamped.maxY, 900)
    }

    func testNegativeScreenCoordinates() {
        let screen = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let frame = CGRect(x: -1600, y: 0, width: 600, height: 190)
        let snapped = PanelGeometry.snappedToTop(frame, screen: screen)
        XCTAssertEqual(snapped.minX, -1600)
        XCTAssertEqual(snapped.maxY, 880)
    }

    func testOversizedPanelFitsScreen() {
        let screen = CGRect(x: 0, y: 0, width: 800, height: 400)
        let result = PanelGeometry.clamped(CGRect(x: 90, y: 90, width: 1000, height: 500), to: screen)
        XCTAssertEqual(result, screen)
    }
}
