# AirPods Privacy Blur

A small macOS prototype that uses AirPods head motion to show a full-screen privacy blur when you turn away from the display.

## Requirements

- macOS 14 or later
- AirPods model with head motion support
- Xcode / Swift toolchain

## Build

```bash
./scripts/build_app.sh
```

The script creates:

```text
dist/AirPods Privacy Blur.app
```

## Use

1. Wear supported AirPods and connect them to the Mac.
2. Launch the app bundle, or run `./run_app.sh` after building.
3. Use the control window or the **AirPods Blur** menu bar item.
4. Choose **Test Blur for 5 Seconds** to confirm the overlay works.
5. Choose **Start AirPods Tracking**.
6. Choose **Calibrate Facing Screen** while looking at the screen.
7. Turn your head left or right. The screen blurs after the configured threshold.
8. Face the screen again and the blur clears.

You can also launch it from Terminal:

```bash
./run_app.sh
```

Launch through `./run_app.sh` or by opening the `.app` bundle. Avoid running `Contents/MacOS/AirPodsPrivacyBlur` directly, because macOS may not attach the app bundle privacy metadata correctly for Motion permission checks.

## Current Behavior

- Uses AirPods yaw motion to detect when you turn away from the calibrated forward direction.
- Covers all connected displays with a click-through blur overlay.
- Uses a short fade-in/fade-out transition for a smoother privacy effect.
- Provides high / medium / low sensitivity presets.

## Notes

- The overlay is click-through, so keyboard and mouse input continue to reach your apps.
- This protects against people near your desk. Screen sharing behavior depends on whether the meeting app captures the whole display or a specific window.
- Motion permission is required; if denied, enable it again in macOS System Settings.
