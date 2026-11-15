#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
ARCHIVE_PATH="$PROJECT_DIR/build/MirageBlade.xcarchive"
EXPORT_DIR="$PROJECT_DIR/dist/AppStore_Export_macOS"
EXPORT_PLIST="$PROJECT_DIR/build/ExportOptions-macOS.plist"
TEAM_ID="${TEAM_ID:-KFDG3WVG6N}"

mkdir -p "$PROJECT_DIR/build" "$EXPORT_DIR"

AUTH_ARGS=(-allowProvisioningUpdates)
if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
    AUTH_ARGS+=(
        -authenticationKeyPath "$ASC_KEY_PATH"
        -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    )
fi

"$XCODEBUILD" archive \
    -project "$PROJECT_DIR/MirageBlade.xcodeproj" \
    -scheme MirageBlade \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    "${AUTH_ARGS[@]}"

"$XCODEBUILD" -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -exportPath "$EXPORT_DIR" \
    "${AUTH_ARGS[@]}"
