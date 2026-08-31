#!/bin/sh

# Xcode Cloud 在每次构建前自动执行此脚本
set -e

echo "--- Installing XcodeGen ---"
# Xcode Cloud 已预装 xcodegen,跳过安装以加速构建
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
