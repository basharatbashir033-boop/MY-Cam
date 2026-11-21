#!/usr/bin/env bash
# Run once on your Mac, inside the my_cam folder: ./setup_ios.sh
set -e

flutter create --platforms=ios --org com.mycam --project-name my_cam .
rm -f test/widget_test.dart

PLIST=ios/Runner/Info.plist
PB=/usr/libexec/PlistBuddy

set_str() {
  $PB -c "Delete :$1" "$PLIST" 2>/dev/null || true
  $PB -c "Add :$1 string $2" "$PLIST"
}

set_str NSCameraUsageDescription "MY Cam uses the camera to show the live mirror preview and take photos."
set_str NSPhotoLibraryAddUsageDescription "MY Cam saves your mirrored photos to your Photos library."
set_str NSPhotoLibraryUsageDescription "MY Cam saves your mirrored photos to your Photos library."
set_str CFBundleDisplayName "MY Cam"

$PB -c "Delete :LSApplicationQueriesSchemes" "$PLIST" 2>/dev/null || true
$PB -c "Add :LSApplicationQueriesSchemes array" "$PLIST"
$PB -c "Add :LSApplicationQueriesSchemes:0 string photos-redirect" "$PLIST"

sed -i '' "s/^# platform :ios, '.*'/platform :ios, '13.0'/" ios/Podfile

flutter pub get
(cd ios && pod install)

echo "Done. Open ios/Runner.xcworkspace once to pick your Team, then: flutter run --release"
