// translator_core.cpp - Translation functionality for WoWTranslate
// Connects to WoWTranslate proxy server for translation with credit tracking

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

// Simple JSON parser for proxy server responses
class SimpleJsonParser {
public:
    static string extractField(const string& json, const string& fieldName) {
        string searchKey = "\"" + fieldName + "\"";
        size_t keyPos = json.find(searchKey);
        if (keyPos == string::npos) {
            return "";
        }

        size_t colonPos = json.find(":", keyPos + searchKey.length());
        if (colonPos == string::npos) {
            return "";
        }

        size_t start = colonPos + 1;
        while (start < json.length() && (json[start] == ' ' || json[start] == '\t' || json[start] == '\n' || json[start] == '\r')) {
            start++;
        }

        if (start >= json.length()) {
            return "";
        }

        // Check if it's a string value (starts with quote)
        if (json[start] == '"') {
            start++;
            size_t end = start;
            while (end < json.length() && json[end] != '"') {
                if (json[end] == '\\' && end + 1 < json.length()) {
                    end += 2; // Skip escaped character
                } else {
                    end++;
                }
            }
            return unescapeJson(json.substr(start, end - start));
        }

        // It's a number or boolean
        size_t end = start;
        while (end < json.length() && json[end] != ',' && json[end] != '}' && json[end] != '\n') {
            end++;
        }
        string value = json.substr(start, end - start);
        // Trim whitespace
        while (!value.empty() && (value.back() == ' ' || value.back() == '\t' || value.back() == '\r')) {
            value.pop_back();
        }
        return value;
    }

    static double extractNumber(const string& json, const string& fieldName) {
        string value = extractField(json, fieldName);
        if (value.empty()) return -1;
        try {
            return stod(value);
        } catch (...) {
            return -1;
        }
    }

private:
    static string unescapeJson(const string& input) {
        string result = input;
        size_t pos = 0;

        // Unescape basic characters
        while ((pos = result.find("\\\"", pos)) != string::npos) {
            result.replace(pos, 2, "\"");
            pos += 1;
        }
        pos = 0;
        while ((pos = result.find("\\\\", pos)) != string::npos) {
            result.replace(pos, 2, "\\");
            pos += 1;
        }
        pos = 0;
        while ((pos = result.find("\\n", pos)) != string::npos) {
            result.replace(pos, 2, "\n");
            pos += 1;
        }
        pos = 0;
        while ((pos = result.find("\\r", pos)) != string::npos) {
            result.replace(pos, 2, "\r");
            pos += 1;
        }
        pos = 0;
        while ((pos = result.find("\\t", pos)) != string::npos) {
            result.replace(pos, 2, "\t");
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
                    pos += 6;
                }
            } else {
                break;
            }
        }

        return result;
    }

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

// Global variables
unique_ptr<TranslationClient> g_translator = nullptr;
char g_translation_buffer[4096] = {0};
char g_error_buffer[256] = {0};

TranslationClient::TranslationClient()
    : hSession(nullptr), hConnect(nullptr), initialized(false), running(false),
      creditsRemaining(-1) {
}

TranslationClient::~TranslationClient() {
    Cleanup();
}

string TranslationClient::GetServerInfo() const {
    return string("https://") + SERVER_HOST + ":" + to_string(SERVER_PORT);
}

bool TranslationClient::Initialize(const string& key) {
    if (initialized) {
        Cleanup();
    }

    apiKey = key;

    LOG_INFO("Initializing translation client");
    LOG_INFO("Server: " + GetServerInfo());

    // Initialize WinHTTP
    hSession = WinHttpOpen(L"WoWTranslate/0.2",
                          WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                          WINHTTP_NO_PROXY_NAME,
                          WINHTTP_NO_PROXY_BYPASS,
                          0);

    if (!hSession) {
        LOG_ERROR("Failed to initialize WinHTTP session");
        return false;
    }

    // Convert host to wide string
    wstring wHost;
    for (const char* p = SERVER_HOST; *p; ++p) {
        wHost += static_cast<wchar_t>(*p);
    }

    // Connect to the proxy server
    hConnect = WinHttpConnect(hSession,
                             wHost.c_str(),
                             static_cast<INTERNET_PORT>(SERVER_PORT),
                             0);

    if (!hConnect) {
        LOG_ERROR("Failed to connect to server: " + string(SERVER_HOST));
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

string TranslationClient::GenerateCacheKey(const string& text, const string& sourceLang, const string& targetLang) {
    return sourceLang + "->" + targetLang + ":" + text;
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

    if (cache.size() > MAX_CACHE_SIZE) {
        size_t removeCount = cache.size() - MAX_CACHE_SIZE / 2;
        for (size_t i = 0; i < removeCount && !cache.empty(); ++i) {
            cache.erase(cache.begin());
        }
    }
}

// Escape a string for JSON
static string escapeJsonString(const string& input) {
    ostringstream ss;
    for (char c : input) {
        switch (c) {
            case '"': ss << "\\\""; break;
            case '\\': ss << "\\\\"; break;
            case '\b': ss << "\\b"; break;
            case '\f': ss << "\\f"; break;
            case '\n': ss << "\\n"; break;
            case '\r': ss << "\\r"; break;
            case '\t': ss << "\\t"; break;
            default:
                if ('\x00' <= c && c <= '\x1f') {
                    ss << "\\u" << hex << setw(4) << setfill('0') << (int)c;
                } else {
                    ss << c;
                }
        }
    }
    return ss.str();
}

string TranslationClient::HttpsRequest(const string& host, const string& path, const string& postData) {
    if (!hConnect) {
        return "";
    }

    wstring wPath(path.begin(), path.end());

    DWORD flags = WINHTTP_FLAG_SECURE;  // Always use HTTPS

    HINTERNET hRequest = WinHttpOpenRequest(hConnect,
                                           L"POST",
                                           wPath.c_str(),
                                           nullptr,
                                           WINHTTP_NO_REFERER,
                                           WINHTTP_DEFAULT_ACCEPT_TYPES,
                                           flags);

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
    } else {
        DWORD error = GetLastError();
        LOG_ERROR("HTTP request failed with error: " + to_string(error));
    }

    WinHttpCloseHandle(hRequest);
    return response;
}

string TranslationClient::ParseTranslationResponse(const string& jsonResponse) {
    // Extract translation from proxy server response
    return SimpleJsonParser::extractField(jsonResponse, "translation");
}

// Synchronous translation via proxy server
TranslationResult TranslationClient::TranslateText(const string& text, string& result,
                                                   const string& sourceLang, const string& targetLang) {
    if (!initialized) {
        LOG_ERROR("Translation client not initialized");
        return TranslationResult::INVALID_PARAMS;
    }

    if (text.empty()) {
        LOG_ERROR("Invalid translation parameters: empty text");
        return TranslationResult::INVALID_PARAMS;
    }

    // Check local cache first (DLL-side cache)
    string cacheKey = GenerateCacheKey(text, sourceLang, targetLang);
    auto cacheIt = cache.find(cacheKey);
    if (cacheIt != cache.end() && (GetTickCount() - cacheIt->second.timestamp) < CACHE_EXPIRY_MS) {
        result = cacheIt->second.translation;
        LOG_DEBUG("Local cache hit for: " + text.substr(0, 50));
        return TranslationResult::SUCCESS;
    }

    CleanExpiredCache();

    // Build JSON request body for proxy server
    // Format: { "apiKey": "WT-xxx", "text": "...", "from": "zh", "to": "en" }
    string requestBody = "{";
    requestBody += "\"apiKey\":\"" + escapeJsonString(apiKey) + "\",";
    requestBody += "\"text\":\"" + escapeJsonString(text) + "\",";
    requestBody += "\"from\":\"" + sourceLang + "\",";
    requestBody += "\"to\":\"" + targetLang + "\"";
    requestBody += "}";

    string path = "/api/translate";

    LOG_DEBUG("Requesting translation from proxy: " + text.substr(0, 50) + " (" + sourceLang + " -> " + targetLang + ")");

    // Make HTTP request to proxy server
    string response = HttpsRequest(SERVER_HOST, path, requestBody);

    if (response.empty()) {
        LOG_ERROR("Empty response from proxy server");
        return TranslationResult::NETWORK_ERROR;
    }

    LOG_DEBUG("Proxy response: " + response.substr(0, 200));

    // Check for error in response
    string error = SimpleJsonParser::extractField(response, "error");
    if (!error.empty()) {
        LOG_ERROR("Proxy error: " + error);

        // Check for specific errors
        if (error.find("Insufficient credits") != string::npos) {
            result = "INSUFFICIENT_CREDITS";
            return TranslationResult::API_ERROR;
        }
        if (error.find("Invalid API key") != string::npos || error.find("Unauthorized") != string::npos) {
            result = "INVALID_API_KEY";
            return TranslationResult::API_ERROR;
        }

        result = error;
        return TranslationResult::API_ERROR;
    }

    // Extract translation
    string translation = ParseTranslationResponse(response);

    if (translation.empty()) {
        LOG_ERROR("Failed to parse translation from response");
        return TranslationResult::API_ERROR;
    }

    // Update credits from response
    double credits = SimpleJsonParser::extractNumber(response, "creditsRemaining");
    if (credits >= 0) {
        creditsRemaining = credits;
    }

    // Cache the result locally
    cache[cacheKey] = CacheEntry(translation);

    result = translation;
    LOG_DEBUG("Translation successful: " + text.substr(0, 30) + " -> " + translation.substr(0, 50));
    return TranslationResult::SUCCESS;
}

// Queue async translation request
bool TranslationClient::TranslateAsync(const string& requestId, const string& text,
                                       const string& sourceLang, const string& targetLang) {
    if (!initialized || !running) {
        return false;
    }

    lock_guard<mutex> lock(requestMutex);
    requestQueue.push(AsyncRequest(requestId, text, sourceLang, targetLang));
    LOG_DEBUG("Async request queued: " + requestId + " (" + sourceLang + " -> " + targetLang + ")");
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

    // Append credits info to the result for the Lua side
    // Format: translation|error|credits
    if (!translation.empty() || !error.empty()) {
        // Credits will be appended by the caller in lua_interface
    }

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

            TranslationResult tr = TranslateText(request.text, translation, request.sourceLang, request.targetLang);

            if (tr != TranslationResult::SUCCESS) {
                // Check if translation contains error message
                if (!translation.empty() && (translation == "INSUFFICIENT_CREDITS" || translation == "INVALID_API_KEY")) {
                    error = translation;
                    translation = "";
                } else {
                    switch (tr) {
                        case TranslationResult::NETWORK_ERROR: error = "network error"; break;
                        case TranslationResult::API_ERROR: error = translation.empty() ? "API error" : translation; break;
                        case TranslationResult::ENCODING_ERROR: error = "encoding error"; break;
                        case TranslationResult::TIMEOUT_ERROR: error = "timeout"; break;
                        case TranslationResult::INVALID_PARAMS: error = "invalid parameters"; break;
                        default: error = "unknown error"; break;
                    }
                    translation = "";
                }
            }

            // Push result to result queue
            {
                lock_guard<mutex> lock(resultMutex);
                resultQueue.push(AsyncResult(request.requestId, translation, error));
            }

            LOG_DEBUG("Async request completed: " + request.requestId);
        } else {
            Sleep(50);
        }
    }

    LOG_INFO("Worker thread stopped");
}
