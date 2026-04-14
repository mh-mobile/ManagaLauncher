#!/bin/bash
set -e

# OTA Distribution Script via Tailscale HTTPS
# Usage:
#   ./scripts/ota-distribute.sh build   - Build IPA and add to builds list
#   ./scripts/ota-distribute.sh serve   - Start HTTPS server
#   ./scripts/ota-distribute.sh         - Build + Serve

COMMAND="${1:-all}"
PORT="${2:-8443}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OTA_DIR="$PROJECT_DIR/.ota"
SCHEME="MangaLauncher"
PROJECT="$PROJECT_DIR/MangaLauncher.xcodeproj"
BUNDLE_ID="com.mh-mobile.MangaYoubi.adhoc"
APP_NAME="マンガ曜日 Adhoc"
BUILDS_DIR="$OTA_DIR/builds"
CERT_DIR="$OTA_DIR/certs"

get_tailscale_hostname() {
    tailscale status --self --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['Self']['DNSName'].rstrip('.'))" 2>/dev/null
}

build_ipa() {
    local ARCHIVE_PATH="$OTA_DIR/tmp/MangaLauncher.xcarchive"
    local IPA_EXPORT="$OTA_DIR/tmp/ipa"

    mkdir -p "$OTA_DIR/tmp" "$BUILDS_DIR"

    # Archive
    echo "==> Archiving..."
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Adhoc \
        -destination 'generic/platform=iOS' \
        -archivePath "$ARCHIVE_PATH" \
        -quiet

    # Extract version info from archive
    local INFO_PLIST="$ARCHIVE_PATH/Products/Applications/MangaLauncher.app/Info.plist"
    local VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
    local BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
    echo "==> Version: ${VERSION} (${BUILD})"

    # Export IPA
    echo "==> Exporting IPA..."
    cat > "$OTA_DIR/tmp/ExportOptions.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>5XJ8CR95CK</string>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
PLIST

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$OTA_DIR/tmp/ExportOptions.plist" \
        -exportPath "$IPA_EXPORT" \
        -quiet

    # Find IPA
    local IPA_FILE=$(find "$IPA_EXPORT" -name "*.ipa" | head -1)
    if [ -z "$IPA_FILE" ]; then
        echo "Error: IPA file not found"
        exit 1
    fi

    # Store in versioned directory
    local BUILD_KEY="${VERSION}_${BUILD}"
    local BUILD_DIR="$BUILDS_DIR/$BUILD_KEY"
    mkdir -p "$BUILD_DIR"
    cp "$IPA_FILE" "$BUILD_DIR/MangaLauncher.ipa"

    # Save build metadata
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    local GIT_HASH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    cat > "$BUILD_DIR/info.json" << INFOJSON
{
    "version": "${VERSION}",
    "build": "${BUILD}",
    "timestamp": "${TIMESTAMP}",
    "gitHash": "${GIT_HASH}",
    "bundleId": "${BUNDLE_ID}"
}
INFOJSON

    # Cleanup temp
    rm -rf "$OTA_DIR/tmp"

    echo "==> Build stored: $BUILD_KEY"
    echo "==> Git: $GIT_HASH"
    echo "==> Time: $TIMESTAMP"
}

generate_pages() {
    local TS_HOSTNAME="$1"
    local BASE_URL="https://${TS_HOSTNAME}:${PORT}"

    # Generate manifest.plist for each build
    for BUILD_DIR in "$BUILDS_DIR"/*/; do
        [ -d "$BUILD_DIR" ] || continue
        local BUILD_KEY=$(basename "$BUILD_DIR")
        local VERSION=$(python3 -c "import json; print(json.load(open('${BUILD_DIR}info.json'))['version'])")
        local BUILD=$(python3 -c "import json; print(json.load(open('${BUILD_DIR}info.json'))['build'])")

        cat > "$BUILD_DIR/manifest.plist" << MANIFEST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>${BASE_URL}/builds/${BUILD_KEY}/MangaLauncher.ipa</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>${BUNDLE_ID}</string>
                <key>bundle-version</key>
                <string>${VERSION}</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>${APP_NAME}</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
MANIFEST
    done

    # Generate index.html with all builds
    # sort -V でバージョン順 (1.9 < 1.10)、-r で新しい順
    local BUILD_ROWS=""
    for BUILD_DIR in $(ls -1d "$BUILDS_DIR"/*/ | sort -Vr); do
        [ -d "$BUILD_DIR" ] || continue
        local BUILD_KEY=$(basename "$BUILD_DIR")
        local INFO_FILE="${BUILD_DIR}info.json"
        [ -f "$INFO_FILE" ] || continue

        local VERSION=$(python3 -c "import json; print(json.load(open('${INFO_FILE}'))['version'])")
        local BUILD=$(python3 -c "import json; print(json.load(open('${INFO_FILE}'))['build'])")
        local TIMESTAMP=$(python3 -c "import json; print(json.load(open('${INFO_FILE}'))['timestamp'])")
        local GIT_HASH=$(python3 -c "import json; print(json.load(open('${INFO_FILE}'))['gitHash'])")
        local INSTALL_URL="itms-services://?action=download-manifest&url=${BASE_URL}/builds/${BUILD_KEY}/manifest.plist"

        BUILD_ROWS="${BUILD_ROWS}
            <div class=\"build-card\">
                <div class=\"build-header\">
                    <span class=\"version\">v${VERSION}</span>
                    <span class=\"build-num\">(${BUILD})</span>
                </div>
                <div class=\"build-meta\">
                    <span>${TIMESTAMP}</span>
                    <span class=\"git-hash\">${GIT_HASH}</span>
                </div>
                <a href=\"${INSTALL_URL}\" class=\"install-btn\">インストール</a>
            </div>"
    done

    cat > "$OTA_DIR/index.html" << HTML
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${APP_NAME} - OTA Distribution</title>
    <style>
        body { font-family: -apple-system, sans-serif; padding: 20px; background: #f5f5f7; margin: 0; }
        .header { text-align: center; padding: 20px 0; }
        .header h1 { font-size: 24px; margin: 0 0 4px; }
        .header p { color: #666; margin: 0; font-size: 14px; }
        .builds { max-width: 500px; margin: 0 auto; }
        .build-card { background: white; border-radius: 12px; padding: 16px; margin-bottom: 12px; box-shadow: 0 1px 4px rgba(0,0,0,0.08); }
        .build-header { margin-bottom: 6px; }
        .version { font-size: 20px; font-weight: 700; }
        .build-num { font-size: 14px; color: #666; margin-left: 4px; }
        .build-meta { font-size: 12px; color: #999; margin-bottom: 12px; display: flex; gap: 12px; }
        .git-hash { font-family: monospace; background: #f0f0f0; padding: 1px 6px; border-radius: 4px; }
        .install-btn { display: block; background: #007AFF; color: white; padding: 10px; border-radius: 10px; text-decoration: none; font-size: 15px; font-weight: 600; text-align: center; }
        .install-btn:active { background: #005EC4; }
        .empty { text-align: center; color: #999; padding: 40px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>${APP_NAME}</h1>
        <p>OTA Distribution</p>
    </div>
    <div class="builds">
        ${BUILD_ROWS:-<p class="empty">ビルドがありません</p>}
    </div>
</body>
</html>
HTML
}

start_server() {
    local TS_HOSTNAME="$1"
    local BASE_URL="https://${TS_HOSTNAME}:${PORT}"

    # Get Tailscale HTTPS cert
    echo "==> Getting Tailscale HTTPS certificate..."
    mkdir -p "$CERT_DIR"
    tailscale cert \
        --cert-file "$CERT_DIR/cert.crt" \
        --key-file "$CERT_DIR/cert.key" \
        "$TS_HOSTNAME"

    # Generate pages
    generate_pages "$TS_HOSTNAME"

    # Kill existing server on same port
    lsof -ti:$PORT | xargs kill -9 2>/dev/null || true

    echo ""
    echo "============================================"
    echo " OTA Distribution Server"
    echo "============================================"
    echo " URL: ${BASE_URL}"
    echo " Ctrl+C to stop"
    echo "============================================"
    echo ""

    python3 << PYEOF
import http.server, ssl, os

os.chdir("$OTA_DIR")

server = http.server.HTTPServer(("0.0.0.0", $PORT), http.server.SimpleHTTPRequestHandler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain("$CERT_DIR/cert.crt", "$CERT_DIR/cert.key")
server.socket = ctx.wrap_socket(server.socket, server_side=True)

print(f"Serving on https://0.0.0.0:$PORT")
server.serve_forever()
PYEOF
}

# Main
TS_HOSTNAME=$(get_tailscale_hostname)
if [ -z "$TS_HOSTNAME" ]; then
    echo "Error: Tailscale is not running or hostname not found"
    exit 1
fi
echo "==> Tailscale hostname: $TS_HOSTNAME"

case "$COMMAND" in
    build)
        build_ipa
        generate_pages "$TS_HOSTNAME"
        echo "==> Done. Run './scripts/ota-distribute.sh serve' to start server."
        ;;
    serve)
        start_server "$TS_HOSTNAME"
        ;;
    all|*)
        build_ipa
        start_server "$TS_HOSTNAME"
        ;;
esac
