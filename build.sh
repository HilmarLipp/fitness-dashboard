#!/bin/bash

cd "$(dirname "$0")"

echo "Kompiliere Transkribieren.app..."

mkdir -p "Transkribieren.app/Contents/MacOS"
mkdir -p "Transkribieren.app/Contents/Resources"

swiftc -o "Transkribieren.app/Contents/MacOS/Transkribieren" \
    -framework Cocoa \
    -framework Foundation \
    -O \
    Transkribieren/main.swift

if [ $? -ne 0 ]; then
    echo "Fehler beim Kompilieren!"
    exit 1
fi

cat > "Transkribieren.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Transkribieren</string>
    <key>CFBundleDisplayName</key>
    <string>Transkribieren</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.transkribieren</string>
    <key>CFBundleVersion</key>
    <string>1.2</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2</string>
    <key>CFBundleExecutable</key>
    <string>Transkribieren</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Audio</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.audio</string>
                <string>public.mp3</string>
                <string>public.mpeg-4-audio</string>
                <string>com.apple.m4a-audio</string>
                <string>com.microsoft.waveform-audio</string>
                <string>public.aiff-audio</string>
                <string>public.aifc-audio</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo ""
echo "✓ Transkribieren.app wurde erstellt!"
echo ""
echo "Installation:"
echo "  xattr -cr Transkribieren.app"
echo "  rm -rf /Applications/Transkribieren.app"
echo "  mv Transkribieren.app /Applications/"
echo "  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Transkribieren.app"
echo ""
echo "Schnellaktion wurde installiert in:"
echo "  ~/Library/Services/Transkribieren.workflow"
echo ""
echo "Rechtsklick auf Audiodateien → Schnellaktionen → Transkribieren"
