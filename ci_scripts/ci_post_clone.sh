#!/bin/sh

# Automatically executed by Xcode Cloud before each build
set -e

echo "--- Installing XcodeGen ---"
# Xcode Cloud has xcodegen pre-installed; skip install if already present
if ! command -v xcodegen &> /dev/null; then
    brew install xcodegen
else
    echo "xcodegen already available: $(xcodegen --version)"
fi

echo "--- Generating Shelfie.xcodeproj ---"
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "--- Listing generated content ---"
ls -la

if [ ! -d "Shelfie.xcodeproj" ]; then
    echo "Error: Shelfie.xcodeproj was not generated"
    exit 1
fi

echo "--- Post-clone complete ---"
