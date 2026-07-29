#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$repo_root/Fixtures/Public/coldsigner-testnet-c03/unsigned.psbt.base64"

swift run \
  --package-path "$repo_root" \
  --sanitize address \
  --scratch-path /tmp/coldsigner-psbt-address-sanitizer \
  ColdSignerPSBTSanitizerRunner \
  "$fixture"
