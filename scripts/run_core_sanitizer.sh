#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

swift run \
  --package-path "$repo_root" \
  --sanitize address \
  --scratch-path /tmp/coldsigner-core-address-sanitizer \
  ColdSignerCoreTestRunner
