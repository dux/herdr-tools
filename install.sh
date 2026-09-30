#!/bin/sh
# Download, verify, and install the latest Herdr Tools release for macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/dux/herdr-tools/main/install.sh | sh
#
# Override the release location for testing:
#   HERDR_TOOLS_BASE=file:///path/to/build sh install.sh

set -eu

REPO="dux/herdr-tools"
ASSET="Herdr_Tools.zip"
BUNDLE_ID="com.dux.ProjectBar"
BASE="${HERDR_TOOLS_BASE:-https://github.com/$REPO/releases/latest/download}"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || die "curl is required"
command -v ditto >/dev/null || die "ditto is required"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say "Downloading $ASSET..."
curl -fsSL "$BASE/$ASSET" -o "$tmp/$ASSET"
curl -fsSL "$BASE/$ASSET.sha256" -o "$tmp/$ASSET.sha256"

say "Verifying checksum..."
expected="$(awk '{print $1}' "$tmp/$ASSET.sha256")"
actual="$(shasum -a 256 "$tmp/$ASSET" | awk '{print $1}')"
[ -n "$expected" ] || die "empty checksum file"
[ "$expected" = "$actual" ] || die "checksum mismatch (expected $expected, got $actual)"

say "Unpacking..."
ditto -x -k "$tmp/$ASSET" "$tmp"
app="$tmp/Herdr_Tools.app"
[ -d "$app" ] || die "Herdr_Tools.app not found in archive"

got_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")"
[ "$got_id" = "$BUNDLE_ID" ] || die "unexpected bundle id: $got_id"

say "Clearing quarantine..."
xattr -dr com.apple.quarantine "$app" 2>/dev/null || true

say "Verifying signature..."
codesign --verify --strict "$app" || die "code signature verification failed"

dest="/Applications"
[ -w "$dest" ] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
say "Installing to $dest/Herdr_Tools.app..."
rm -rf "$dest/Herdr_Tools.app"
ditto "$app" "$dest/Herdr_Tools.app"

say "Launching..."
open "$dest/Herdr_Tools.app"
say "Installed Herdr Tools to $dest/Herdr_Tools.app"
