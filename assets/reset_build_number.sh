#!/bin/bash

echo "--- Resetting build number! ---"

cd "$SRCROOT"

# Set VERSION
sed -i -e "/VERSION =/ s/= .*/= 0.0.1/" "Wally‘s Hand/Config.xcconfig"

# Set BUILD_NUMBER
sed -i -e "/BUILD_NUMBER =/ s/= .*/= 0/" "Wally‘s Hand/Config.xcconfig"

rm "Wally‘s Hand/Config.xcconfig-e"

echo "--- Done! ---"
