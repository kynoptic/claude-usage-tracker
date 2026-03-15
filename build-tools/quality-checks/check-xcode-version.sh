#!/usr/bin/env bash
# Validate Xcode version is 16.0 or later
# The project uses PBXFileSystemSynchronizedRootGroup (Xcode 16+ only)
set -euo pipefail

# Get Xcode version
xcode_path=$(/usr/bin/xcode-select --print-path 2>/dev/null || echo "")

if [ -z "${xcode_path}" ]; then
    echo "Error: Xcode is not installed or xcode-select is not configured"
    echo "Run: xcode-select --install"
    exit 1
fi

# Extract version from Xcode path (e.g., /Applications/Xcode.app)
xcode_version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${xcode_path}/../Info.plist" 2>/dev/null || echo "")

if [ -z "${xcode_version}" ]; then
    echo "Error: Could not determine Xcode version"
    exit 1
fi

# Extract major version number
major_version=$(echo "${xcode_version}" | cut -d. -f1)

if [ "${major_version}" -lt 16 ]; then
    echo "Error: Xcode 16.0+ required, but found Xcode ${xcode_version}"
    echo "The project uses PBXFileSystemSynchronizedRootGroup format (Xcode 16+ feature)"
    echo "Install Xcode 16+: https://developer.apple.com/download/"
    exit 1
fi

echo "✓ Xcode ${xcode_version} (Xcode 16+ requirement satisfied)"
