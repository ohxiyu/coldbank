#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command_name in rg python3 sips shasum; do
  command -v "$command_name" >/dev/null || {
    echo "error: required release audit tool is missing: $command_name"
    exit 1
  }
done

./scripts/check_repo.sh
git diff --check

if rg --line-number '\.package\(url:.*(from:|branch:|revision:)' Package.swift Packages/ColdSignerTransport/Package.swift; then
  echo "error: direct remote dependency is not pinned with exact:"
  exit 1
fi

required_documents=(
  THIRD_PARTY_NOTICES.md
  docs/SBOM-v0.1.json
  docs/USER-GUIDE.md
  docs/RELEASE-CHECKLIST.md
  docs/DEVICE-TEST-PLAN.md
  docs/EXTERNAL-REVIEW-SCOPE.md
  docs/ASSET-PROVENANCE.md
)
for document in "${required_documents[@]}"; do
  if [[ ! -s "$document" ]]; then
    echo "error: missing release document: $document"
    exit 1
  fi
done

json_documents=(
  docs/SBOM-v0.1.json
  Fixtures/Public/manifest.schema.json
  Fixtures/Public/coldsigner-testnet-c03/manifest.json
  Fixtures/Public/coldsigner-testnet-c03/decoded.json
)
for document in "${json_documents[@]}"; do
  python3 -m json.tool "$document" >/dev/null
done

pins=(
  'bdk-swift|3.0.0|5bc9c3cddf203f6aa147d77364782bf095e4f84e'
  'urkit|9.0.0|4323721f7f91331d8cfa64ee54cfbaba106a5b20'
  'wolfbase|5.3.1|d7219c703316956c42a7f47f926a442d082f043f'
  'swift-algorithms|1.2.1|87e50f483c54e6efd60e885f7f5aa946cee68023'
  'swift-numerics|1.1.1|0c0290ff6b24942dadb83a929ffaaa1481df04a2'
)
for pin in "${pins[@]}"; do
  IFS='|' read -r identity version revision <<<"$pin"
  if ! rg -q "\"identity\" : \"$identity\"" Packages/ColdSignerTransport/Package.resolved; then
    echo "error: missing resolved dependency: $identity"
    exit 1
  fi
  if ! rg -q "\"version\" : \"$version\"" Packages/ColdSignerTransport/Package.resolved; then
    echo "error: resolved version drift: $identity"
    exit 1
  fi
  if ! rg -q "\"revision\" : \"$revision\"" Packages/ColdSignerTransport/Package.resolved; then
    echo "error: resolved revision drift: $identity"
    exit 1
  fi
  if ! rg -q "$revision" docs/SBOM-v0.1.json; then
    echo "error: SBOM revision drift: $identity"
    exit 1
  fi
done

if [[ ! -s ColdSignerApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png ]]; then
  echo "error: release app icon is missing"
  exit 1
fi

icon_properties="$(sips -g pixelWidth -g pixelHeight -g hasAlpha \
  ColdSignerApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)"
if ! rg -q 'pixelWidth: 1024' <<<"$icon_properties" \
    || ! rg -q 'pixelHeight: 1024' <<<"$icon_properties" \
    || ! rg -q 'hasAlpha: no' <<<"$icon_properties"; then
  echo "error: release app icon must be opaque 1024x1024"
  exit 1
fi
icon_sha="$(shasum -a 256 \
  ColdSignerApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png \
  | awk '{print $1}')"
if ! rg -q "$icon_sha" docs/ASSET-PROVENANCE.md; then
  echo "error: app icon digest is missing or stale in asset provenance"
  exit 1
fi
if ! rg -q '"filename" : "AppIcon-1024.png"' \
  ColdSignerApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json; then
  echo "error: release app icon is not bound to the asset catalog"
  exit 1
fi

echo "release metadata audit: passed"
