.PHONY: bootstrap generate check core-test psbt-sanitizer psbt-fuzz release-audit test

bootstrap: generate check

generate:
	@command -v xcodegen >/dev/null || (echo "error: install XcodeGen with 'brew install xcodegen'" && exit 1)
	xcodegen generate

check:
	./scripts/check_repo.sh

core-test:
	./scripts/run_core_tests.sh

psbt-sanitizer:
	./scripts/run_psbt_sanitizer.sh

psbt-fuzz:
	./scripts/run_psbt_fuzzer.sh

release-audit:
	./scripts/audit_release.sh

test: generate
	xcodebuild test \
		-project ColdSigner.xcodeproj \
		-scheme ColdSigner \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		CODE_SIGNING_ALLOWED=NO
