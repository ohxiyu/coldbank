#!/usr/bin/env bash
# Release-gate check: the built ColdSigner binary must not link networking
# frameworks or reference socket-level symbols. Source scanning cannot see
# what the final binary links, so this runs against the .app itself.
#
# Usage: scripts/verify_release_binary.sh <path to ColdSigner.app or executable>
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this check requires macOS (otool/nm)"
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <path to ColdSigner.app or its executable>"
  exit 1
fi

target="$1"
if [[ -d "$target" ]]; then
  plist="$target/Info.plist"
  executable="ColdSigner"
  if [[ -f "$plist" ]]; then
    executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null || echo ColdSigner)"
  fi
  target="$target/$executable"
fi

if [[ ! -f "$target" ]]; then
  echo "error: binary not found: $target"
  exit 1
fi

banned_frameworks='CFNetwork|/Network\.framework/|NetworkExtension|WebKit|CloudKit|MultipeerConnectivity|libnetwork'
if otool -L "$target" | rg --quiet "$banned_frameworks"; then
  otool -L "$target" | rg "$banned_frameworks"
  echo "error: binary links a banned networking framework"
  exit 1
fi

banned_symbols='_socket$|_connect$|_getaddrinfo$|_CFSocketCreate|NSURLSession|_nw_connection'
if nm -u "$target" 2>/dev/null | rg --quiet "$banned_symbols"; then
  nm -u "$target" | rg "$banned_symbols"
  echo "error: binary references a banned networking symbol"
  exit 1
fi

echo "release binary network guard: passed"
