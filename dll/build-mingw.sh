#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OBJ_DIR="$BUILD_DIR/obj"
MINHOOK_SRC="$BUILD_DIR/minhook-src"
OUTPUT_DLL="$BUILD_DIR/WoWTranslate.dll"
CLIENT_DIR="/Users/sanjaybhat/WoW Install/TurtleWoW eng client 1.18.1"
CLIENT_DLL="$CLIENT_DIR/WoWTranslate.dll"
MINGW_BIN="/opt/homebrew/opt/mingw-w64/bin"

export PATH="$MINGW_BIN:$PATH"

CC="${CC:-i686-w64-mingw32-gcc}"
CXX="${CXX:-i686-w64-mingw32-g++}"
OBJDUMP="${OBJDUMP:-x86_64-w64-mingw32-objdump}"

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: required tool not found: $1" >&2
        exit 1
    fi
}

require_tool git
require_tool file
require_tool "$CC"
require_tool "$CXX"
require_tool "$OBJDUMP"

mkdir -p "$BUILD_DIR" "$OBJ_DIR"

if [ ! -f "$MINHOOK_SRC/include/MinHook.h" ]; then
    if [ -e "$MINHOOK_SRC" ]; then
        echo "ERROR: $MINHOOK_SRC exists but does not look like a MinHook checkout" >&2
        exit 1
    fi
    git clone --depth 1 https://github.com/TsudaKageyu/minhook.git "$MINHOOK_SRC"
fi

find "$OBJ_DIR" -type f \( -name '*.o' -o -name '*.d' \) -delete

COMMON_DEFS=(
    -DWIN32_LEAN_AND_MEAN
    -DNOMINMAX
    -D_WIN32_WINNT=0x0600
)

COMMON_INCLUDES=(
    -I"$SCRIPT_DIR/include"
    -I"$MINHOOK_SRC/include"
    -I"$SCRIPT_DIR/third_party"
)

CFLAGS=(
    -m32
    -O2
    -Wall
    -Wextra
    "${COMMON_DEFS[@]}"
    "${COMMON_INCLUDES[@]}"
)

CXXFLAGS=(
    -m32
    -std=c++17
    -O2
    -Wall
    -Wextra
    -DMINHOOK_AVAILABLE
    -DJSON_HAS_FILESYSTEM=0
    "${COMMON_DEFS[@]}"
    "${COMMON_INCLUDES[@]}"
)

MINHOOK_SOURCES=(
    "$MINHOOK_SRC/src/buffer.c"
    "$MINHOOK_SRC/src/hook.c"
    "$MINHOOK_SRC/src/trampoline.c"
    "$MINHOOK_SRC/src/hde/hde32.c"
)

CPP_SOURCES=(
    "$SCRIPT_DIR/src/dllmain.cpp"
    "$SCRIPT_DIR/src/lua_interface.cpp"
    "$SCRIPT_DIR/src/translator_core.cpp"
    "$SCRIPT_DIR/src/logging.cpp"
    "$SCRIPT_DIR/src/utils.cpp"
)

OBJECTS=()

for source in "${MINHOOK_SOURCES[@]}"; do
    object="$OBJ_DIR/minhook_$(basename "${source%.*}").o"
    "$CC" "${CFLAGS[@]}" -c "$source" -o "$object"
    OBJECTS+=("$object")
done

for source in "${CPP_SOURCES[@]}"; do
    object="$OBJ_DIR/$(basename "${source%.*}").o"
    "$CXX" "${CXXFLAGS[@]}" -c "$source" -o "$object"
    OBJECTS+=("$object")
done

# With this Homebrew GCC, driver-level -static and -shared do not reliably keep
# the driver-added C++ runtime static. Keep MinGW runtimes in an explicit group.
"$CXX" -shared -m32 -o "$OUTPUT_DLL" \
    "${OBJECTS[@]}" \
    -static-libgcc -static-libstdc++ -no-pthread \
    -Wl,-Bstatic -Wl,--start-group -lstdc++ -lgcc -lgcc_eh -lwinpthread -Wl,--end-group -Wl,-Bdynamic \
    -lwinhttp -lkernel32 -luser32 -lshell32 -ladvapi32

FILE_OUTPUT="$(file "$OUTPUT_DLL")"
DLL_NAMES="$("$OBJDUMP" -p "$OUTPUT_DLL" | grep 'DLL Name' || true)"

echo
echo "Verification: file WoWTranslate.dll"
echo "$FILE_OUTPUT"

echo
echo "Verification: x86_64-w64-mingw32-objdump -p WoWTranslate.dll | grep 'DLL Name'"
echo "$DLL_NAMES"

if ! grep -q 'PE32' <<<"$FILE_OUTPUT" || grep -q 'PE32+' <<<"$FILE_OUTPUT" || ! grep -q 'Intel 80386' <<<"$FILE_OUTPUT"; then
    echo "ERROR: verification failed: output is not a 32-bit PE32 Intel 80386 DLL" >&2
    exit 1
fi

if grep -Eiq 'libstdc\+\+-6\.dll|libgcc_s_.*\.dll|libwinpthread-1\.dll' <<<"$DLL_NAMES"; then
    echo "ERROR: verification failed: MinGW runtime DLL dependency detected" >&2
    exit 1
fi

if [ ! -d "$CLIENT_DIR" ]; then
    echo "ERROR: client directory does not exist: $CLIENT_DIR" >&2
    exit 1
fi

cp -f "$OUTPUT_DLL" "$CLIENT_DLL"

echo
echo "DLL size:"
stat -f '%z bytes' "$OUTPUT_DLL"

echo
echo "Confirmed outputs:"
ls -l "$OUTPUT_DLL"
ls -l "$CLIENT_DLL"
