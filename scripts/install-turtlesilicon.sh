#!/bin/bash
# WoWTranslate Installation Script for TurtleSilicon (macOS)
# This script installs the addon and DLL to your Turtle WoW client

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================"
echo "WoWTranslate Installer for TurtleSilicon"
echo "============================================"
echo ""

# Default game path (can be overridden)
DEFAULT_GAME_PATH="$HOME/Downloads/twmoa_1180"
GAME_PATH="${1:-$DEFAULT_GAME_PATH}"

# Get script directory (where the addon files are)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Game path: $GAME_PATH"
echo "Source path: $SCRIPT_DIR"
echo ""

# Check if game directory exists
if [ ! -d "$GAME_PATH" ]; then
    echo -e "${RED}Error: Game directory not found at $GAME_PATH${NC}"
    echo "Usage: $0 [path-to-wow-folder]"
    echo "Example: $0 ~/Downloads/twmoa_1180"
    exit 1
fi

# Check for WoW.exe or similar
if [ ! -f "$GAME_PATH/WoW.exe" ] && [ ! -f "$GAME_PATH/WoW_tweaked.exe" ]; then
    echo -e "${YELLOW}Warning: WoW.exe not found in $GAME_PATH${NC}"
    echo "Continuing anyway..."
fi

# Create AddOns directory if it doesn't exist
ADDONS_DIR="$GAME_PATH/Interface/AddOns"
mkdir -p "$ADDONS_DIR"

# Install addon
echo "Installing WoWTranslate addon..."
if [ -d "$SCRIPT_DIR/Interface/AddOns/WoWTranslate" ]; then
    rm -rf "$ADDONS_DIR/WoWTranslate"
    cp -r "$SCRIPT_DIR/Interface/AddOns/WoWTranslate" "$ADDONS_DIR/"
    echo -e "${GREEN}✓ Addon installed to $ADDONS_DIR/WoWTranslate${NC}"
else
    echo -e "${RED}Error: Addon source not found at $SCRIPT_DIR/Interface/AddOns/WoWTranslate${NC}"
    exit 1
fi

# Check for DLL
DLL_SOURCE=""
if [ -f "$SCRIPT_DIR/dll/build/bin/Release/WoWTranslate.dll" ]; then
    DLL_SOURCE="$SCRIPT_DIR/dll/build/bin/Release/WoWTranslate.dll"
elif [ -f "$SCRIPT_DIR/WoWTranslate.dll" ]; then
    DLL_SOURCE="$SCRIPT_DIR/WoWTranslate.dll"
elif [ -f "$SCRIPT_DIR/release/WoWTranslate.dll" ]; then
    DLL_SOURCE="$SCRIPT_DIR/release/WoWTranslate.dll"
fi

if [ -n "$DLL_SOURCE" ]; then
    echo "Installing WoWTranslate DLL..."
    cp "$DLL_SOURCE" "$GAME_PATH/"
    echo -e "${GREEN}✓ DLL installed to $GAME_PATH/WoWTranslate.dll${NC}"
else
    echo -e "${YELLOW}⚠ DLL not found. You need to:${NC}"
    echo "  1. Download pre-built DLL from GitHub Releases, OR"
    echo "  2. Build on Windows using: cd dll && build.bat"
    echo "  Then place WoWTranslate.dll in $GAME_PATH/"
fi

# Update dlls.txt
DLLS_TXT="$GAME_PATH/dlls.txt"
echo "Updating dlls.txt..."

if [ -f "$DLLS_TXT" ]; then
    # Check if WoWTranslate.dll is already in the file
    if grep -q "WoWTranslate.dll" "$DLLS_TXT"; then
        echo -e "${GREEN}✓ WoWTranslate.dll already in dlls.txt${NC}"
    else
        echo "WoWTranslate.dll" >> "$DLLS_TXT"
        echo -e "${GREEN}✓ Added WoWTranslate.dll to dlls.txt${NC}"
    fi
else
    # Create new dlls.txt
    echo "WoWTranslate.dll" > "$DLLS_TXT"
    echo -e "${GREEN}✓ Created dlls.txt with WoWTranslate.dll${NC}"
fi

echo ""
echo "============================================"
echo -e "${GREEN}Installation complete!${NC}"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Get a Google Cloud Translation API key"
echo "   https://console.cloud.google.com/apis/credentials"
echo ""
echo "2. Launch Turtle WoW via TurtleSilicon"
echo ""
echo "3. In-game, type:"
echo "   /wt key YOUR_API_KEY"
echo "   /wt status"
echo ""
echo "4. Test translation:"
echo "   /wt test 你好"
echo ""

# Show installed files
echo "Installed files:"
echo "  $ADDONS_DIR/WoWTranslate/"
ls -la "$ADDONS_DIR/WoWTranslate/" 2>/dev/null || true
echo ""
if [ -f "$GAME_PATH/WoWTranslate.dll" ]; then
    echo "  $GAME_PATH/WoWTranslate.dll"
    ls -la "$GAME_PATH/WoWTranslate.dll"
fi
echo ""
echo "  $DLLS_TXT:"
cat "$DLLS_TXT"
