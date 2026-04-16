#!/bin/bash
# SignalScope Project Setup Script
# This script generates the Xcode project using XcodeGen

set -e

cd "$(dirname "$0")"

echo "🔧 SignalScope Project Setup"
echo "============================"

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 XcodeGen not found. Installing via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Please install Homebrew first:"
        echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo "   Then run this script again."
        exit 1
    fi
    brew install xcodegen
fi

echo "🏗️  Generating Xcode project..."
xcodegen generate

echo ""
echo "✅ SignalScope.xcodeproj created successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Open SignalScope.xcodeproj in Xcode"
echo "   2. Select your Development Team in Signing & Capabilities"
echo "   3. Enable these capabilities:"
echo "      - Access WiFi Information"
echo "      - Hotspot Configuration"
echo "   4. Build and run on a real device (most features need real hardware)"
echo ""
echo "🚀 To open in Xcode now, run:"
echo "   open SignalScope.xcodeproj"
