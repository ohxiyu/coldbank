#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v rg >/dev/null || {
  echo "error: ripgrep (rg) is required for repository checks"
  exit 1
}

required_files=(
  README.md
  SECURITY.md
  docs/PRD-v0.1.md
  docs/SECURITY-BASELINE.md
  docs/COMPATIBILITY.md
  docs/DEVELOPMENT-PLAN.md
  docs/DEPENDENCIES.md
  project.yml
  Package.swift
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -s "$repo_root/$relative_path" ]]; then
    echo "error: missing or empty $relative_path"
    exit 1
  fi
done

"$repo_root/scripts/verify_no_network.sh"

if rg --line-number --hidden --glob '!.git/**' --glob '!scripts/check_repo.sh' \
  '(abandon abandon abandon|xprv[1-9A-HJ-NP-Za-km-z]{20,}|-----BEGIN (EC |RSA )?PRIVATE KEY-----)' \
  "$repo_root"; then
  echo "error: possible secret fixture found"
  exit 1
fi

echo "repository checks: passed"
