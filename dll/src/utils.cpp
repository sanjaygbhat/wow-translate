// utils.cpp - Utility functions for WoWTranslate

#include <windows.h>
#include <string>
#include <vector>
#include <sstream>
#include <algorithm>
#include <iomanip>
#include <ctime>
#include <cstdint>

#include "../include/utils.h"

using namespace std;

#if defined(__GNUC__) && !defined(_MSC_VER)
namespace {

bool IsReadableProtection(DWORD protect) {
    if (protect & (PAGE_GUARD | PAGE_NOACCESS)) {
        return false;
    }

    DWORD baseProtect = protect & 0xff;
    return baseProtect == PAGE_READONLY ||
           baseProtect == PAGE_READWRITE ||
           baseProtect == PAGE_WRITECOPY ||
           baseProtect == PAGE_EXECUTE_READ ||
           baseProtect == PAGE_EXECUTE_READWRITE ||
           baseProtect == PAGE_EXECUTE_WRITECOPY;
}

bool IsReadableRange(const void* address, size_t length) {
    if (address == nullptr || length == 0) {
        return false;
    }

    auto current = reinterpret_cast<const unsigned char*>(address);
    auto end = current + length;

    while (current < end) {
        MEMORY_BASIC_INFORMATION mbi;
        if (VirtualQuery(current, &mbi, sizeof(mbi)) == 0) {
            return false;
        }

        if (mbi.State != MEM_COMMIT || !IsReadableProtection(mbi.Protect)) {
            return false;
        }

        auto regionEnd = reinterpret_cast<const unsigned char*>(mbi.BaseAddress) + mbi.RegionSize;
        current = min(end, regionEnd);
    }

    return true;
}

bool IsReadableString(const char* value, size_t maxLength) {
    if (value == nullptr) {
        return false;
    }

    for (size_t i = 0; i < maxLength; ++i) {
        if (!IsReadableRange(value + i, 1)) {
            return false;
        }
        if (value[i] == '\0') {
            return true;
        }
    }

    return false;
}

} // namespace
#endif

string GetCurrentTimestamp() {
    time_t now = time(0);
    tm timeinfo;
#if defined(_MSC_VER) || defined(__MINGW32__)
    localtime_s(&timeinfo, &now);
#else
    localtime_r(&now, &timeinfo);
#endif

    ostringstream oss;
    oss << put_time(&timeinfo, "%Y-%m-%d %H:%M:%S");
    return oss.str();
}

string GetDllPath() {
    char path[MAX_PATH];
    HMODULE hModule = nullptr;

    // Get handle to this DLL
    if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                          GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                          (LPCSTR)&GetDllPath, &hModule) == 0) {
        return "";
    }

    // Get the full path
    if (GetModuleFileNameA(hModule, path, MAX_PATH) == 0) {
        return "";
    }

    return string(path);
}

vector<string> SplitString(const string& str, char delimiter) {
    vector<string> tokens;
    stringstream ss(str);
    string token;

    while (getline(ss, token, delimiter)) {
        tokens.push_back(token);
    }

    return tokens;
}

string TrimString(const string& str) {
    size_t start = str.find_first_not_of(" \t\n\r\f\v");
    if (start == string::npos) {
        return "";
    }

    size_t end = str.find_last_not_of(" \t\n\r\f\v");
    return str.substr(start, end - start + 1);
}

bool IsValidMemoryAddress(void* addr) {
    if (addr == nullptr) {
        return false;
    }

    MEMORY_BASIC_INFORMATION mbi;
    if (VirtualQuery(addr, &mbi, sizeof(mbi)) == 0) {
        return false;
    }

    return (mbi.State == MEM_COMMIT) &&
           (mbi.Protect & (PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE |
                          PAGE_READONLY | PAGE_READWRITE));
}

void* SafeGetProcAddress(HMODULE hModule, const char* procName) {
    if (!hModule || !procName) {
        return nullptr;
    }

#if defined(__GNUC__) && !defined(_MSC_VER)
    if (!IsReadableRange(hModule, sizeof(IMAGE_DOS_HEADER))) {
        return nullptr;
    }

    uintptr_t procValue = reinterpret_cast<uintptr_t>(procName);
    if (procValue > 0xFFFF && !IsReadableString(procName, MAX_PATH)) {
        return nullptr;
    }

    return reinterpret_cast<void*>(GetProcAddress(hModule, procName));
#else
    __try {
        return GetProcAddress(hModule, procName);
    } __except(EXCEPTION_EXECUTE_HANDLER) {
        return nullptr;
    }
#endif
}
