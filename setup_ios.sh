#!/usr/bin/env bash
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

flutter pub get
echo "Setup done."
