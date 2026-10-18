#!/bin/bash
# Builds MediaRemoteAdapter.framework and MediaRemoteAdapterTestClient without CMake.
# Usage: build.sh FRAMEWORKS_DIR EXECUTABLES_DIR
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORKS_DIR="$1"
EXECUTABLES_DIR="$2"
FRAMEWORK="$FRAMEWORKS_DIR/MediaRemoteAdapter.framework"
BINARY="$FRAMEWORK/Versions/A/MediaRemoteAdapter"
TEST_CLIENT="$EXECUTABLES_DIR/MediaRemoteAdapterTestClient"

if [ -f "$BINARY" ] && [ -f "$TEST_CLIENT" ] \
   && [ -z "$(find "$ROOT/src" "$ROOT/include" "$0" -newer "$BINARY" -print -quit)" ]; then
  exit 0
fi

ARCH_FLAGS=()
for arch in ${ARCHS:-arm64 x86_64}; do ARCH_FLAGS+=(-arch "$arch"); done
MIN_VERSION="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET:-14.0}"

SOURCES=(
  src/adapter/env.m src/adapter/get.m src/adapter/globals.m src/adapter/keys.m
  src/adapter/now_playing.m src/adapter/repeat.m src/adapter/seek.m src/adapter/send.m
  src/adapter/shuffle.m src/adapter/speed.m src/adapter/stream.m src/adapter/test.m
  src/private/MediaRemote.m src/utility/Debounce.m src/utility/helpers.m
)

rm -rf "$FRAMEWORK"
mkdir -p "$FRAMEWORK/Versions/A/Resources" "$FRAMEWORK/Versions/A/Headers" "$EXECUTABLES_DIR"

(cd "$ROOT" && xcrun clang "${ARCH_FLAGS[@]}" "$MIN_VERSION" -dynamiclib -fobjc-arc -fvisibility=default \
  -Iinclude -Isrc \
  -install_name @rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  "${SOURCES[@]}" -o "$BINARY")
cp "$ROOT/include/MediaRemoteAdapter.h" "$FRAMEWORK/Versions/A/Headers/"
cp "$ROOT/LICENSE" "$FRAMEWORK/Versions/A/Resources/LICENSE"
cat > "$FRAMEWORK/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
<key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>0.7.7</string>
<key>CFBundleVersion</key><string>0.7.7</string>
</dict></plist>
PLIST
(cd "$FRAMEWORK/Versions" && ln -sfn A Current)
(cd "$FRAMEWORK" && ln -sfn Versions/Current/MediaRemoteAdapter MediaRemoteAdapter \
  && ln -sfn Versions/Current/Resources Resources && ln -sfn Versions/Current/Headers Headers)

(cd "$ROOT" && xcrun clang "${ARCH_FLAGS[@]}" "$MIN_VERSION" -fobjc-arc -Isrc/test \
  -framework Foundation -framework MediaPlayer \
  src/test/main.m src/test/NowPlayingTest.m -o "$TEST_CLIENT")

# Ad-hoc so perl can load it in development builds; release.yml re-signs every Mach-O with Developer ID.
codesign --force --sign - "$FRAMEWORK"
codesign --force --sign - "$TEST_CLIENT"
