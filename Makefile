SHELL := /bin/bash

.PHONY: test coverage build-device

MODULES_DIR := Modules
COVERAGE_RESULT_REL := .build/coverage.xcresult
COVERAGE_RESULT := $(MODULES_DIR)/$(COVERAGE_RESULT_REL)

## FileBrowserTests・PhotoViewerTestsをシミュレータ上で実行する
test:
	@SIMULATOR_NAME=$$(xcrun simctl list devices available | grep -m1 'iPhone' | sed -E 's/^ *([^(]+) \(.*/\1/' | sed -E 's/[[:space:]]+$$//'); \
	echo "Running FileBrowserTests and PhotoViewerTests on simulator: $$SIMULATOR_NAME"; \
	set -o pipefail && cd $(MODULES_DIR) && xcodebuild test \
		-scheme Modules-Package \
		-destination "platform=iOS Simulator,name=$$SIMULATOR_NAME"

## ViewModel・Serviceのテストカバレッジを計測する（ViewModels/Servicesディレクトリ配下のみ）
coverage:
	@rm -rf $(COVERAGE_RESULT)
	@mkdir -p $(MODULES_DIR)/.build
	@SIMULATOR_NAME=$$(xcrun simctl list devices available | grep -m1 'iPhone' | sed -E 's/^ *([^(]+) \(.*/\1/' | sed -E 's/[[:space:]]+$$//'); \
	echo "Measuring coverage on simulator: $$SIMULATOR_NAME"; \
	set -o pipefail && cd $(MODULES_DIR) && xcodebuild test \
		-scheme Modules-Package \
		-destination "platform=iOS Simulator,name=$$SIMULATOR_NAME" \
		-enableCodeCoverage YES \
		-resultBundlePath $(COVERAGE_RESULT_REL)
	@echo ""
	@echo "=== ViewModel / Service coverage ==="
	@xcrun xccov view --report --json $(COVERAGE_RESULT) | swift Scripts/PrintCoverage.swift

## 実機（iOS device）向けにアプリがビルドできるかを署名なしでチェックする
build-device:
	@if [ ! -f Config/Local.xcconfig ]; then \
		echo "Config/Local.xcconfig not found; generating an unsigned placeholder for this check"; \
		printf 'DEVELOPMENT_TEAM =\nPRODUCT_BUNDLE_IDENTIFIER = fuziki.my-preview-2.devicecheck\n' > Config/Local.xcconfig; \
	fi
	set -o pipefail && xcodebuild build \
		-project my-preview-2.xcodeproj \
		-scheme my-preview-2 \
		-destination 'generic/platform=iOS' \
		-configuration Debug \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY=""
