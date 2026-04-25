#!/bin/bash
echo "[Harness] Generating changelog..."
npx conventional-changelog -p angular -i CHANGELOG.md -s 2>/dev/null || echo "⚠ conventional-changelog not available"

if command -v yq &> /dev/null && command -v npx &> /dev/null; then
    VER=$(npx standard-version --dry-run 2>/dev/null | grep 'tagging version' | awk '{print $4}')
    if [ -n "$VER" ]; then
        yq e ".suggested_version = \"$VER\"" -i .harness/harness.yml
        echo "Suggested version: $VER"
    fi
fi