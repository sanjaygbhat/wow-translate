// translator_core.cpp - Translation functionality for WoWTranslate
// Google Translate API client with async support
// Hardcoded Chinese (zh) to English (en) translation

#include <windows.h>
#include <winhttp.h>
#include <string>
#include <algorithm>
#include <sstream>
#include <iomanip>
#include <codecvt>
#include <locale>
#include <vector>
#include <cstdio>

#include "../include/translator_core.h"
#include "../include/logging.h"
#include "../include/utils.h"

using namespace std;

// Simple JSON parser for Google Translate API responses
class SimpleJsonParser {
public:
    static string extractTranslatedText(const string& json) {
        // Look for "translatedText" key
        string searchKey = "\"translatedText\"";
        size_t keyPos = json.find(searchKey);
        if (keyPos == string::npos) {
            return "";
        }

        // Find the colon after the key
        size_t colonPos = json.find(":", keyPos + searchKey.length());
        if (colonPos == string::npos) {
            return "";
        }

        // Skip whitespace after colon and find the opening quote
        size_t start = colonPos + 1;
        while (start < json.length() && (json[start] == ' ' || json[start] == '\t' || json[start] == '\n' || json[start] == '\r')) {
            start++;
        }

        if (start >= json.length() || json[start] != '"') {
            return "";
        }

        start++; // Skip the opening quote
        size_t end = json.find("\"", start);
        if (end == string::npos) {
            return "";
        }

        string result = json.substr(start, end - start);

        // Unescape basic JSON characters and Unicode sequences
        size_t pos = 0;
        while ((pos = result.find("\\\"", pos)) != string::npos) {
            result.replace(pos, 2, "\"");
            pos += 1;
        }
        pos = 0;
        while ((pos = result.find("\\\\", pos)) != string::npos) {
            result.replace(pos, 2, "\\");
            pos += 1;
        }

        // Handle Unicode escape sequences \uXXXX
        pos = 0;
        while ((pos = result.find("\\u", pos)) != string::npos) {
            if (pos + 5 < result.length()) {
                string hexStr = result.substr(pos + 2, 4);
                try {
                    unsigned int codepoint = stoul(hexStr, nullptr, 16);
                    string utf8_char = ConvertCodepointToUTF8(codepoint);
                    result.replace(pos, 6, utf8_char);
                    pos += utf8_char.length();
                } catch (...) {
                    pos += 6; // Skip invalid unicode sequence
                }
            } else {
                break;
            }
        }

        return result;
    }

private:
    static string ConvertCodepointToUTF8(unsigned int codepoint) {
        string result;

        if (codepoint <= 0x7F) {
            result += static_cast<char>(codepoint);
        } else if (codepoint <= 0x7FF) {
            result += static_cast<char>(0xC0 | (codepoint >> 6));
            result += static_cast<char>(0x80 | (codepoint & 0x3F));
        } else if (codepoint <= 0xFFFF) {
            result += static_cast<char>(0xE0 | (codepoint >> 12));
            result += static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
            result += static_cast<char>(0x80 | (codepoint & 0x3F));
        } else if (codepoint <= 0x10FFFF) {
            result += static_cast<char>(0xF0 | (codepoint >> 18));
            result += static_cast<char>(0x80 | ((codepoint >> 12) & 0x3F));
            result += static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
            result += static_cast<char>(0x80 | (codepoint & 0x3F));
        }

        return result;
    }
};

// UTF-8 helper class
class UTF8Helper {
public:
    static string FixUTF8String(const string& input) {
        if (IsValidUTF8(input)) {
            return input;
        }
        return input;
    }

private:
    static bool IsValidUTF8(const string& str) {
        size_t i = 0;
        while (i < str.length()) {
            unsigned char c = str[i];
            if (c < 0x80) {
                i++;
            } else if ((c >> 5) == 0x06) {
                if (++i >= str.length() || (str[i] & 0xC0) != 0x80) return false;
                i++;
            } else if ((c >> 4) == 0x0E) {
                if (++i >= str.length() || (str[i] & 0xC0) != 0x80) return false;
                if (++i >= str.length() || (str[i] & 0xC0) != 0x80) return false;
                i++;
            } else if ((c >> 3) == 0x1E) {
                if (++i >= str.length() || (str[i] & 0xC0) != 0x80) return false;
                if (++i >= str.length() || (str[i] & 0xC0) != 0x80) return false;
                if (++i >= str.length() || (str[i] & 0xC0) != 0x80) return false;
                i++;
            } else {
                return false;
            }
        }
        return true;
    }
};

// Global variables
unique_ptr<TranslationClient> g_translator = nullptr;
char g_translation_buffer[4096] = {0};
char g_error_buffer[256] = {0};

TranslationClient::TranslationClient()
    : hSession(nullptr), hConnect(nullptr), initialized(false), running(false) {
}

TranslationClient::~TranslationClient() {
    Cleanup();
}

bool TranslationClient::Initialize(const string& key) {
    if (initialized) {
        Cleanup();
    }

    apiKey = key;

    LOG_INFO("Initializing translation client with API key");

    // Initialize WinHTTP
    hSession = WinHttpOpen(L"WoWTranslate/0.1",
                          WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                          WINHTTP_NO_PROXY_NAME,
                          WINHTTP_NO_PROXY_BYPASS,
                          0);

    if (!hSession) {
        LOG_ERROR("Failed to initialize WinHTTP session");
        return false;
    }

    // Connect to Google Translate API
    hConnect = WinHttpConnect(hSession,
                             L"translation.googleapis.com",
                             INTERNET_DEFAULT_HTTPS_PORT,
                             0);

    if (!hConnect) {
        LOG_ERROR("Failed to connect to Google Translate API");
        WinHttpCloseHandle(hSession);
        hSession = nullptr;
        return false;
    }

    // Start worker thread for async translations
    running = true;
    workerThread = thread(&TranslationClient::WorkerThreadFunc, this);

    initialized = true;
    LOG_INFO("Translation client initialized successfully");
    return true;
}

void TranslationClient::Cleanup() {
    // Stop worker thread
    if (running) {
        running = false;
        if (workerThread.joinable()) {
            workerThread.join();
        }
    }

    if (hConnect) {
        WinHttpCloseHandle(hConnect);
        hConnect = nullptr;
    }

    if (hSession) {
        WinHttpCloseHandle(hSession);
        hSession = nullptr;
    }

    cache.clear();
    initialized = false;
    LOG_INFO("Translation client cleanup complete");
}

string TranslationClient::UrlEncode(const string& text) {
    ostringstream encoded;
    encoded.fill('0');
    encoded << hex;

    for (unsigned char c : text) {
        if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') {
            encoded << c;
        } else {
            encoded << uppercase;
            encoded << '%' << setw(2) << static_cast<int>(c);
            encoded << nouppercase;
        }
    }

    return encoded.str();
}

string TranslationClient::GenerateCacheKey(const string& text) {
    // Hardcoded zh->en, so just use text as key
    return "zh->en:" + text;
}

void TranslationClient::CleanExpiredCache() {
    DWORD currentTime = GetTickCount();
    auto it = cache.begin();

    while (it != cache.end()) {
        if (currentTime - it->second.timestamp > CACHE_EXPIRY_MS) {
            it = cache.erase(it);
        } else {
            ++it;
        }
    }

    // Limit cache size
    if (cache.size() > MAX_CACHE_SIZE) {
        size_t removeCount = cache.size() - MAX_CACHE_SIZE / 2;
        for (size_t i = 0; i < removeCount && !cache.empty(); ++i) {
            cache.erase(cache.begin());
        }
    }
}

string TranslationClient::HttpsRequest(const string& host, const string& path, const string& postData) {
    if (!hConnect) {
        return "";
    }

    // Convert path to wide string
    wstring wPath(path.begin(), path.end());

    // Open request
    HINTERNET hRequest = WinHttpOpenRequest(hConnect,
                                           L"POST",
                                           wPath.c_str(),
                                           nullptr,
                                           WINHTTP_NO_REFERER,
                                           WINHTTP_DEFAULT_ACCEPT_TYPES,
                                           WINHTTP_FLAG_SECURE);

    if (!hRequest) {
        LOG_ERROR("Failed to open HTTP request");
        return "";
    }

    // Set headers
    wstring headers = L"Content-Type: application/json\r\n";
    WinHttpAddRequestHeaders(hRequest, headers.c_str(), (DWORD)-1, WINHTTP_ADDREQ_FLAG_ADD);

    // Send request
    BOOL result = WinHttpSendRequest(hRequest,
                                    WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                                    (LPVOID)postData.c_str(), (DWORD)postData.length(),
                                    (DWORD)postData.length(), 0);

    string response;
    if (result && WinHttpReceiveResponse(hRequest, nullptr)) {
        DWORD bytesAvailable = 0;
        char buffer[8192];

        while (WinHttpQueryDataAvailable(hRequest, &bytesAvailable) && bytesAvailable > 0) {
            DWORD bytesRead = 0;
            DWORD bytesToRead = min(bytesAvailable, (DWORD)(sizeof(buffer) - 1));

            if (WinHttpReadData(hRequest, buffer, bytesToRead, &bytesRead)) {
                buffer[bytesRead] = '\0';
                response += string(buffer, bytesRead);
            } else {
                break;
            }
        }
    }

    WinHttpCloseHandle(hRequest);
    return response;
}

string TranslationClient::ParseTranslationResponse(const string& jsonResponse) {
    return SimpleJsonParser::extractTranslatedText(jsonResponse);
}

// Synchronous translation (zh -> en hardcoded)
TranslationResult TranslationClient::TranslateText(const string& text, string& result) {
    if (!initialized) {
        LOG_ERROR("Translation client not initialized");
        return TranslationResult::INVALID_PARAMS;
    }

    if (text.empty()) {
        LOG_ERROR("Invalid translation parameters: empty text");
        return TranslationResult::INVALID_PARAMS;
    }

    // Check cache first
    string cacheKey = GenerateCacheKey(text);
    auto cacheIt = cache.find(cacheKey);
    if (cacheIt != cache.end() && (GetTickCount() - cacheIt->second.timestamp) < CACHE_EXPIRY_MS) {
        result = cacheIt->second.translation;
        LOG_DEBUG("Translation cache hit for: " + text);
        return TranslationResult::SUCCESS;
    }

    // Clean expired cache entries periodically
    CleanExpiredCache();

    // Build request body - hardcoded zh -> en
    string requestBody = "{"
        "\"q\":\"" + text + "\","
        "\"source\":\"zh\","
        "\"target\":\"en\","
        "\"format\":\"text\""
        "}";

    string path = "/language/translate/v2?key=" + apiKey;

    LOG_DEBUG("Making translation request for: " + text);

    // Make HTTP request
    string response = HttpsRequest("translation.googleapis.com", path, requestBody);

    if (response.empty()) {
        LOG_ERROR("Empty response from translation API");
        return TranslationResult::NETWORK_ERROR;
    }

    // Parse response
    string translation = ParseTranslationResponse(response);

    if (translation.empty()) {
        LOG_ERROR("Failed to parse translation from response: " + response.substr(0, 200));
        return TranslationResult::API_ERROR;
    }

    // Fix UTF-8 encoding issues
    translation = UTF8Helper::FixUTF8String(translation);

    // Cache the result
    cache[cacheKey] = CacheEntry(translation);

    result = translation;
    LOG_DEBUG("Translation successful: " + text + " -> " + translation);
    return TranslationResult::SUCCESS;
}

// Queue async translation request
bool TranslationClient::TranslateAsync(const string& requestId, const string& text) {
    if (!initialized || !running) {
        return false;
    }

    lock_guard<mutex> lock(requestMutex);
    requestQueue.push(AsyncRequest(requestId, text));
    LOG_DEBUG("Async request queued: " + requestId);
    return true;
}

// Poll for completed translation
bool TranslationClient::PollResult(string& requestId, string& translation, string& error) {
    lock_guard<mutex> lock(resultMutex);

    if (resultQueue.empty()) {
        return false;
    }

    AsyncResult result = resultQueue.front();
    resultQueue.pop();

    requestId = result.requestId;
    translation = result.translation;
    error = result.error;
    return true;
}

// Get count of pending requests
size_t TranslationClient::GetPendingCount() {
    lock_guard<mutex> lock(requestMutex);
    return requestQueue.size();
}

// Worker thread for async translations
void TranslationClient::WorkerThreadFunc() {
    LOG_INFO("Worker thread started");

    while (running) {
        AsyncRequest request;
        bool hasRequest = false;

        // Get next request from queue
        {
            lock_guard<mutex> lock(requestMutex);
            if (!requestQueue.empty()) {
                request = requestQueue.front();
                requestQueue.pop();
                hasRequest = true;
            }
        }

        if (hasRequest) {
            LOG_DEBUG("Processing async request: " + request.requestId);

            string translation;
            string error;

            TranslationResult tr = TranslateText(request.text, translation);

            if (tr != TranslationResult::SUCCESS) {
                switch (tr) {
                    case TranslationResult::NETWORK_ERROR: error = "network error"; break;
                    case TranslationResult::API_ERROR: error = "API error"; break;
                    case TranslationResult::ENCODING_ERROR: error = "encoding error"; break;
                    case TranslationResult::TIMEOUT_ERROR: error = "timeout"; break;
                    case TranslationResult::INVALID_PARAMS: error = "invalid parameters"; break;
                    default: error = "unknown error"; break;
                }
                translation = "";
            }

            // Push result to result queue
            {
                lock_guard<mutex> lock(resultMutex);
                resultQueue.push(AsyncResult(request.requestId, translation, error));
            }

            LOG_DEBUG("Async request completed: " + request.requestId);
        } else {
            // No requests, sleep a bit
            Sleep(50);
        }
    }

    LOG_INFO("Worker thread stopped");
}
