# MY Cam – WYSIWYG Mirror Camera (iPhone 8 Plus, iOS 16)

What you see in the preview is exactly what is saved. Raise your right hand in
the preview and the saved photo shows it on the same side. Text on a shirt looks
the same in the preview and in the saved photo. Works on the **front and back**
camera.

## How the mirror works

| Camera | Raw photo from sensor | Preview on screen | Saved photo |
|--------|-----------------------|-------------------|-------------|
| Front  | not mirrored          | mirrored (by the camera plugin) | raw photo flipped horizontally |
| Back   | not mirrored          | flipped horizontally by MY Cam (`Transform`) | raw photo flipped horizontally |

Preview and saved photo go through the same horizontal flip, and the flip is
never undone. The saving code lives in `lib/services/mirror_processor.dart`
(runs in a background isolate, so the preview never lags).

## Features

- Full-screen live preview, portrait, iPhone-Camera-style UI
- Big white shutter, front/back flip, flash toggle, gallery thumbnail (left)
- Highest resolution (`ResolutionPreset.max`, 12MP on iPhone 8 Plus), JPEG quality 100
- Auto exposure + auto focus, tap to focus, slight brightness/contrast/sharpness boost
- Saves straight into the Photos Camera Roll
- Back camera uses the real flash; the front camera has none, so the screen flashes white

## Requirements

- A Mac with **Xcode 14.x or newer** and CocoaPods (`sudo gem install cocoapods` or `brew install cocoapods`)
- **Flutter 3.16+** (`flutter doctor` must show no errors for iOS)
- iPhone 8 Plus (iOS 16) and a USB cable (the camera does not work in the Simulator)
- A free Apple ID is enough for personal installs

## Build and run

1. Put this folder on your Mac and open a terminal inside it.
2. Run the one-time setup (creates the `ios/` project, adds camera and photo
   permissions, sets the app name to "MY Cam", installs pods):
   ```bash
   ./setup_ios.sh
   ```
3. Connect the iPhone, unlock it, tap **Trust This Computer**.
   On iOS 16 turn on **Settings > Privacy & Security > Developer Mode**
   (the phone restarts once).
4. Open `ios/Runner.xcworkspace` in Xcode once:
   **Runner > Signing & Capabilities > Team** = your Apple ID, and change the
   Bundle Identifier to something unique, e.g. `com.yourname.mycam`.
5. Run in release mode for the smoothest result on the A11 chip:
   ```bash
   flutter run --release
   ```
6. First launch: allow **Camera** and **Photos** access.
   If you refused, enable them in Settings > MY Cam.
7. First time only on the phone, if asked: Settings > General > VPN & Device
   Management > trust your developer profile.

With a free Apple ID the app expires after 7 days; run step 5 again to reinstall.

## Folder structure

```
lib/main.dart                       app start, portrait lock, theme
lib/screens/camera_screen.dart      UI, preview mirroring, capture flow
lib/services/camera_service.dart    camera controller, flash, focus, switching
lib/services/mirror_processor.dart  flips + enhances the photo (background isolate)
lib/services/gallery_service.dart   permission + saving to Camera Roll
```

## Settings you can change

In `camera_screen.dart`:
- `kFillScreen` – `true` full-screen preview (sides of the 4:3 photo are cropped
  on screen only; the saved photo still has the full frame). `false` shows the
  full 4:3 frame like the iPhone Camera app.
- `kFrontPreviewIsMirroredByPlugin` – leave `true`. If the front preview ever
  looks un-mirrored on your device, set it to `false`.

In `mirror_processor.dart`:
- `enhance` – `false` skips brightness/sharpen for the fastest save.
- `jpegQuality` – 100 is the maximum.

## Quick self-test

1. Hold up your right hand, take a photo with the front camera. In Photos the
   hand is on the same side as in the preview.
2. Wear or hold something with text; the text reads the same in preview and in Photos
   (mirrored text in both).
3. Repeat with the back camera.

## Troubleshooting

- **Black screen / "Camera access is off"**: Settings > MY Cam > Camera.
- **Photo not in Photos**: Settings > MY Cam > Photos > Add Photos Only (or All Photos).
- **`pod install` fails**: `cd ios && pod repo update && pod install`.
- **Signing error**: pick your Team and a unique Bundle Identifier in Xcode.
- **Saving takes 1-3 seconds after a shot**: that is the 12MP image being mirrored
  at full quality in the background; you can keep shooting and the thumbnail
  shows a spinner until it is saved.
