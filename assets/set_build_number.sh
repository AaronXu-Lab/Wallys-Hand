#!/bin/bash

echo "--- Setting build number! ---"

cd "$SRCROOT"

# Set VERSION
sed -i -e "/VERSION =/ s/= .*/= 0.0.1/" Loop-Just/Config.xcconfig

# Set BUILD_NUMBER
latest_commit_number=$(git rev-list --count HEAD)
sed -i -e "/BUILD_NUMBER =/ s/= .*/= $latest_commit_number/" Loop-Just/Config.xcconfig

rm Loop-Just/Config.xcconfig-e

echo "--- Done! ---"
