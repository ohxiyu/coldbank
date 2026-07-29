#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for command_name in swift base64; do
  command -v "$command_name" >/dev/null || {
    echo "error: required fuzzing tool is missing: $command_name"
    exit 1
  }
done

swift_version="$(swift --version | head -1)"
if [[ "$swift_version" != *"Swift version 6.3.3"* ]]; then
  echo "error: PSBT fuzzing requires the pinned Swift.org 6.3.3 toolchain"
  echo "actual: $swift_version"
  exit 1
fi

fuzz_root="${PSBT_FUZZ_WORK_ROOT:-$(mktemp -d /tmp/coldsigner-psbt-fuzz.XXXXXX)}"
corpus_dir="$fuzz_root/corpus"
artifact_dir="$fuzz_root/artifacts"
mkdir -p "$corpus_dir" "$artifact_dir"

base64 -D \
  < "$repo_root/Fixtures/Public/coldsigner-testnet-c03/unsigned.psbt.base64" \
  > "$corpus_dir/coldsigner-testnet-c03.psbt"

swift run \
  --package-path "$repo_root" \
  --configuration release \
  --sanitize fuzzer \
  --scratch-path /tmp/coldsigner-psbt-libfuzzer \
  -Xswiftc -parse-as-library \
  ColdSignerPSBTFuzzer \
  -runs="${PSBT_FUZZ_RUNS:-25000}" \
  -seed=20260718 \
  -max_len=2097152 \
  -timeout=5 \
  -rss_limit_mb=8192 \
  -print_final_stats=1 \
  -artifact_prefix="$artifact_dir/" \
  "$corpus_dir"
