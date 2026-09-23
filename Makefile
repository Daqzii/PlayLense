# Alltag am Mac. Einmalig: brew install xcodegen
.PHONY: project build test validate bundle clean

project:
	xcodegen generate

SIM_UDID := $(shell xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; c=sorted([(rt,x) for rt,xs in d.items() if 'iOS' in rt for x in xs if 'iPad' in x['name']], key=lambda t: t[0]); print(c[-1][1]['udid'] if c else '')")

build: project
	xcodebuild build -project PlayLense.xcodeproj -scheme PlayLense -destination "platform=iOS Simulator,id=$(SIM_UDID)" CODE_SIGNING_ALLOWED=NO | grep -E "error:|warning: |BUILD" || true

test: project
	xcodebuild test -project PlayLense.xcodeproj -scheme PlayLense -destination "platform=iOS Simulator,id=$(SIM_UDID)" CODE_SIGNING_ALLOWED=NO | grep -E "error:|Test Case|Executed|BUILD|TEST" || true

validate:
	python3 tools/exercises.py validate

bundle: validate
	python3 tools/exercises.py bundle

clean:
	rm -rf PlayLense.xcodeproj .dd .spm
