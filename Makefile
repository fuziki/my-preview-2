SHELL := /bin/bash

.PHONY: test

MODULES_DIR := Modules

## FileBrowserTests・PhotoViewerTestsをシミュレータ上で実行する
test:
	@SIMULATOR_NAME=$$(xcrun simctl list devices available | grep -m1 'iPhone' | sed -E 's/^ *([^(]+) \(.*/\1/' | sed -E 's/[[:space:]]+$$//'); \
	echo "Running FileBrowserTests and PhotoViewerTests on simulator: $$SIMULATOR_NAME"; \
	set -o pipefail && cd $(MODULES_DIR) && xcodebuild test \
		-scheme Modules-Package \
		-destination "platform=iOS Simulator,name=$$SIMULATOR_NAME"
