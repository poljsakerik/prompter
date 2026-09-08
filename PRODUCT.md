# Product

<!-- impeccable:product-schema 1 -->

## Platform
Native macOS desktop utility.

## Stack
Swift and AppKit, confirmed native macOS by the user. Swift Package Manager for a dependency-free build.

## Users
A Mac user reading scripts while recording with an external camera, not the built-in webcam.

## Product Purpose
Keep a compact teleprompter close to the camera to minimize eye movement away from the lens.

## Operating Context
The user's Mac monitor. The overlay must be draggable rather than fixed at the notch or top-left corner, and reach the physical top of the screen.

## Capabilities and Constraints
Adjustable width, text speed, and font size. Floating script playback. Position is user-controlled. Local scripts, no accounts or network services.

## Brand Commitments
User reference: https://github.com/saif0200/notchprompt. Preserve the compact black teleprompter approach and native controls rather than inventing a new visual identity.

## Product Principles
- Put readable script text nearest the camera, above controls.
- Let the user place the overlay; do not force notch alignment.
- Keep setup separate from the recording surface.

## Open Decisions
Product name is provisionally Prompter. Default width follows the reference; height and persistence are implementation conveniences.
