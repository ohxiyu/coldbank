.PHONY: bootstrap generate check core-test coordinator-test test

bootstrap: generate check

generate:
	@command -v xcodegen >/dev/null || (echo "error: install XcodeGen with 'brew install xcodegen'" && exit 1)
	xcodegen generate

check:
	./scripts/check_repo.sh

core-test:
	./scripts/run_core_tests.sh

coordinator-test:
	cd Coordinator && npm ci && npm run typecheck && npm test

test: generate
	xcodebuild test \
		-project ColdSigner.xcodeproj \
		-scheme ColdSigner \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		CODE_SIGNING_ALLOWED=NO
