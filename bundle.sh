#!/bin/bash
# Bundle FenHouse for macOS

APP=FenHouse.app
BIN=fenhouse

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$BIN"
cp native/libfen_shim_jni.dylib "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
 <key>CFBundleName</key><string>FenHouse</string>
 <key>CFBundleIdentifier</key><string>com.example.fenhouse</string>
 <key>CFBundleExecutable</key><string>fenhouse</string>
 <key>CFBundlePackageType</key><string>APPL</string>
 <key>LSMinimumSystemVersion</key><string>12.0</string>
</dict></plist>
PLIST
open "$APP"
