#!/bin/bash

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null
then
    echo "XcodeGen could not be found. Please install it using 'brew install xcodegen'."
    exit
fi

# Generate project
xcodegen generate

echo "Xcode project generated successfully."
