#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/ColdSigner.app"
  exit 2
fi

app_bundle="$1"
binary="$app_bundle/ColdSigner"
info_plist="$app_bundle/Info.plist"

if [[ ! -d "$app_bundle" || ! -f "$binary" || ! -f "$info_plist" ]]; then
  echo "error: incomplete ColdSigner app bundle: $app_bundle"
  exit 1
fi

banned_runtime_pattern='(CFNetwork|CloudKit|NetworkExtension|WebKit|MultipeerConnectivity|StoreKit|libcurl|libnetwork)'
banned_symbol_pattern='(_OBJC_CLASS_\$_NSURLSession|_OBJC_CLASS_\$_WKWebView|_OBJC_CLASS_\$_CKContainer|_nw_connection_|_SCNetworkReachability|_CFHTTP)'

linked_frameworks="$(otool -L "$binary")"
if rg --line-number "$banned_runtime_pattern" <<<"$linked_frameworks"; then
  echo "error: banned network/cloud runtime linked into ColdSigner"
  exit 1
fi

undefined_symbols="$(nm -u "$binary" 2>/dev/null || true)"
if rg --line-number "$banned_symbol_pattern" <<<"$undefined_symbols"; then
  echo "error: banned network/cloud symbol referenced by ColdSigner"
  exit 1
fi

banned_plist_keys=(
  UIBackgroundModes
  NSLocalNetworkUsageDescription
  NSBonjourServices
  NSAppTransportSecurity
)
for key in "${banned_plist_keys[@]}"; do
  if /usr/libexec/PlistBuddy -c "Print :$key" "$info_plist" >/dev/null 2>&1; then
    echo "error: banned Info.plist capability present: $key"
    exit 1
  fi
done

if find "$app_bundle" -type d -name '*.appex' -print -quit | rg -q .; then
  echo "error: unexpected app extension embedded in ColdSigner"
  exit 1
fi

if codesign -d "$app_bundle" >/dev/null 2>&1; then
  entitlements="$(codesign -d --entitlements :- "$app_bundle" 2>&1 || true)"
  if rg --line-number '(associated-domains|icloud|aps-environment|com\.apple\.developer\.networking)' <<<"$entitlements"; then
    echo "error: banned network/cloud entitlement present"
    exit 1
  fi
fi

echo "built app audit: passed"
echo "$linked_frameworks"
