# FullBars — common dev commands
# Usage: make <target>

SCHEME       := FullBars
DESTINATION  := platform=iOS Simulator,name=iPhone 16,OS=latest
RESULT       := TestResults.xcresult

.PHONY: test test-ui test-all coverage lint clean

## Run unit tests (fast, ~1 s)
test:
	@echo "▸ Running unit tests…"
	xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:FullBarsTests \
		-enableCodeCoverage YES \
		-resultBundlePath $(RESULT) \
		| xcbeautify || true

## Run UI tests (requires simulator, ~3 min)
test-ui:
	@echo "▸ Running UI tests…"
	xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:FullBarsUITests \
		| xcbeautify || true

## Run all tests (unit + UI)
test-all: test test-ui

## Print line-coverage percentage from the last test run
coverage:
	@xcrun xccov view --report --json $(RESULT) \
		| python3 -c 'import json,sys; r=json.load(sys.stdin); print("Line coverage: %.2f%%" % (r["lineCoverage"]*100))'

## Run SwiftLint (install with `brew install swiftlint`)
lint:
	swiftlint lint --strict

## Remove build artifacts
clean:
	rm -rf $(RESULT) DerivedData/ build/
	@echo "▸ Cleaned."
