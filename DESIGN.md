---
name: Prompter
description: A camera-adjacent native macOS reading utility.
colors:
  overlay-background: "#000000"
  overlay-text: "#ffffff"
  overlay-status: "#b8b8b8"
typography:
  script:
    fontFamily: "macOS system font"
    fontSize: "24pt"
    fontWeight: 500
  editor:
    fontFamily: "macOS system font"
    fontSize: "16pt"
    fontWeight: 400
  label:
    fontFamily: "macOS system font"
    fontSize: "13pt"
    fontWeight: 500
spacing:
  compact: "4pt"
  related: "8pt"
  workspace: "24pt"
---

# Design System: Prompter

## Overview

A reading instrument, not a presentation surface. Follow the user's Notchprompt reference: a compact black reading strip paired with a conventional native macOS workspace. The overlay minimizes reflected light while the user records beside an external camera.

## Colors

The overlay uses the fixed monochrome tokens above. The editor uses AppKit semantic text, secondary-label, text-background, and window-background colors. Accent and focus treatments come from macOS and the user's appearance settings; do not hard-code the screenshot's blue accent or dark workspace.

## Typography

Use the system font and SF Symbols throughout. Script text is medium weight and user-adjustable. The editor uses regular body text. Workspace heading is 22 pt semibold, inspector heading 17 pt semibold, helper text 12 pt, and status/metadata 11 pt. Setting values use monospaced digits, not a monospace display family.

Script line spacing is 22% of the selected font size; paragraph spacing is 45%. Preserve user-authored paragraph breaks. Long words can wrap when the user deliberately combines narrow width with large type.

## Layout

The reading strip puts text first, 10 pt from the top and 14 pt from each side. A 1 pt separator and 40 pt transport row follow it. Resizing preserves the top edge, not the center. The default width is 600 pt. Below 360 pt the status label hides; all transport actions remain.

The workspace has a flexible editor and a 248 pt settings column, separated by a native rule and 24 pt gutters. Use native layout constraints. Group each setting label, value, and slider closely; leave 20 pt between inspector groups.

## Elevation & Depth

The overlay uses the platform window shadow and no decorative surface effects. Its window level is above the menu bar to allow physical-top placement. The editor uses native window and button rendering, including the OS's current material treatment.

## Shapes

The overlay is rectangular so it can meet a screen edge without a gap. Editor windows and buttons retain system-owned shapes. Icons come from SF Symbols; the drag handle is two small horizontal strokes.

## Components

- **Script viewport:** non-editable cached TextKit layout. Drag to reposition; wheel or trackpad scroll to seek and pause. A complete first line must fit at every font setting.
- **Transport:** icon-only native buttons with tooltips and accessibility labels. Play changes to Pause, and is disabled without a script. Status says Ready, Playing, Paused, or Finished where space permits.
- **Settings:** continuous native sliders with named labels and live unit values. Height adjusts upward when necessary to fit large text.
- **Editor:** plain-text NSTextView with undo, native selection, scrolling, and keyboard editing. Import/export use system file panels; failures use native alert sheets.
- **Motion:** only user-requested script playback. No entrance animation for the overlay. The playback timer stops when paused or hidden.

## Do's and Don'ts

- Do keep reading text above controls and nearest the camera.
- Do preserve native focus, selection, keyboard, and appearance behavior.
- Do make position a user choice and provide physical-top snapping.
- Don't center the overlay on the notch or add a title bar above the script.
- Don't imply that floating-window content is hidden from screen recordings.
