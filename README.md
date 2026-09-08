# Prompter

A native macOS teleprompter for recording with an external camera. Inspired by [Notchprompt](https://github.com/saif0200/notchprompt), with a draggable overlay instead of fixed notch placement.

- Floats above other windows and snaps to the screen's top edge.
- Adjustable width, scrolling speed, font size, and height.
- Plain-text editor with import/export and automatic local saving.
- Remembers the script, settings, and overlay position.
- Built with Swift and AppKit, with no third-party dependencies.

## Build and run

Requires macOS 13+ and Swift 6+ through Xcode or Command Line Tools.

```sh
./scripts/build-app.sh
open dist/Prompter.app
```

You can move the app into Applications. Builds are ad-hoc signed for local use, not notarized for distribution.

## Usage

Paste your script into the editor, adjust the sliders, and drag the overlay near your camera. Use **Snap to top** to remove the gap above it. Scrolling manually pauses playback; hiding the overlay also pauses it.

| Shortcut | Action |
| --- | --- |
| `⌥⌘P` | Play / pause |
| `⌥⌘R` | Restart, paused |
| `⌥⌘J` | Back five seconds |
| `⌥⌘O` | Show / hide overlay |
| `⌥⌘=` / `⌥⌘-` | Increase / decrease speed |

These shortcuts work while other apps have focus, without Accessibility permission.

## Tests

```sh
swift test
swift run Prompter --smoke-test
```

The smoke test opens temporary windows and captures them under `.impeccable/review/`. Faithful screenshots require Screen Recording permission; normal app use does not.

## Privacy

Scripts and settings stay on your Mac. No accounts, telemetry, or camera access. **The overlay is visible in screen recordings and screen sharing.** Share an individual app window if you need to exclude it.
