#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v rg >/dev/null || {
  echo "error: ripgrep (rg) is required for the network guard"
  exit 1
}
source_roots=(
  "$repo_root/ColdSignerApp"
  "$repo_root/Sources"
  "$repo_root/Packages/ColdSignerTransport/Sources"
)

banned_pattern='(^|[^A-Za-z])(import[[:space:]]+(Network|NetworkExtension|WebKit|CloudKit|MultipeerConnectivity)|URLSession|URLRequest|WKWebView|NWConnection|CFSocket|GCDAsyncSocket|MCSession|CKContainer)'

if rg --line-number --glob '*.swift' --glob '*.m' --glob '*.mm' --glob '*.h' "$banned_pattern" "${source_roots[@]}"; then
  echo "error: first-party networking or cloud API found"
  exit 1
fi

if rg --line-number '(com\.apple\.developer\.(associated-domains|icloud-container-identifiers|networking)|UIBackgroundModes|NSLocalNetworkUsageDescription|NSAllowsArbitraryLoads)' \
  "$repo_root/project.yml" "$repo_root/ColdSignerApp/Resources"; then
  echo "error: network/cloud entitlement or configuration found"
  exit 1
fi

echo "network guard: passed"
