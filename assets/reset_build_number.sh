#!/bin/bash

echo "--- Resetting build number! ---"

cd "$SRCROOT"

# Set VERSION
sed -i -e "/VERSION =/ s/= .*/= 0.0.1/" Loop-Just/Config.xcconfig

# Set BUILD_NUMBER
sed -i -e "/BUILD_NUMBER =/ s/= .*/= 0/" Loop-Just/Config.xcconfig

rm Loop-Just/Config.xcconfig-e

echo "--- Done! ---"
