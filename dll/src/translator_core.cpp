// translator_core.cpp - Translation providers for WoWTranslate 2.0
// Calls local user-configured HTTPS translation providers directly.

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
#include <winhttp.h>
#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <map>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#ifdef _MSC_VER
#pragma warning(push, 0)
#endif
#include "json.hpp"
#include "gtx_parser.h"
#ifdef _MSC_VER
#pragma warning(pop)
#endif

#include "../include/translator_core.h"
#include "../include/logging.h"
#include "../include/utils.h"

using namespace std;
using json = nlohmann::json;

namespace {

string ToLowerCopy(string value) {
    transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
        return static_cast<char>(tolower(c));
    });
    return value;
}

wstring ToWide(const string& value) {
    return wstring(value.begin(), value.end());
}

void ReplaceAll(string& value, const string& from, const string& to) {
    if (from.empty()) {
        return;
    }

    size_t pos = 0;
    while ((pos = value.find(from, pos)) != string::npos) {
        value.replace(pos, from.length(), to);
        pos += to.length();
    }
}

string JsonTemplateEscape(const string& value) {
    // error_handler_t::replace: chat text can contain invalid UTF-8 (server
    // truncates at 255 bytes mid-character; Turtle language-garbling). A bare
    // dump() THROWS on it — on the worker thread that killed the process.
    string dumped = json(value).dump(-1, ' ', false, json::error_handler_t::replace);
    if (dumped.length() >= 2 && dumped.front() == '"' && dumped.back() == '"') {
        return dumped.substr(1, dumped.length() - 2);
    }
    return dumped;
}

string MaskSecret(const string& value) {
    if (value.empty()) {
        return "";
    }
    if (value.length() <= 6) {
        return "******";
    }
    return value.substr(0, 3) + "..." + value.substr(value.length() - 3);
}

bool IsSensitiveQueryName(const string& name) {
    string lower = ToLowerCopy(name);
    return lower == "key" || lower == "api_key" || lower == "apikey" ||
           lower == "token" || lower == "access_token";
}

string MaskUrl(const string& url) {
    size_t queryPos = url.find('?');
    if (queryPos == string::npos) {
        return url;
    }

    string result = url.substr(0, queryPos + 1);
    string query = url.substr(queryPos + 1);
    size_t pos = 0;
    bool first = true;

    while (pos <= query.length()) {
        size_t amp = query.find('&', pos);
        string part = (amp == string::npos) ? query.substr(pos) : query.substr(pos, amp - pos);
        size_t eq = part.find('=');

        if (!first) {
            result += "&";
        }
        first = false;

        if (eq != string::npos && IsSensitiveQueryName(part.substr(0, eq))) {
            result += part.substr(0, eq + 1) + "***";
        } else {
            result += part;
        }

        if (amp == string::npos) {
            break;
        }
        pos = amp + 1;
    }

    return result;
}

string ProviderName(TranslationProvider provider) {
    switch (provider) {
        case TranslationProvider::GOOGLE: return "google";
        case TranslationProvider::OPENAI_COMPATIBLE: return "openai";
        case TranslationProvider::CUSTOM_HTTP: return "custom";
        case TranslationProvider::GOOGLE_FREE: return "google_free";
        default: return "unknown";
    }
}

string BasicHtmlDecode(string value) {
    ReplaceAll(value, "&amp;", "&");
    ReplaceAll(value, "&lt;", "<");
    ReplaceAll(value, "&gt;", ">");
    ReplaceAll(value, "&quot;", "\"");
    ReplaceAll(value, "&#39;", "'");
    ReplaceAll(value, "&apos;", "'");
    return value;
}

string TrimCopy(const string& value) {
    return TrimString(value);
}

string JsonErrorMessage(const json& parsed, DWORD httpStatus) {
    try {
        if (parsed.contains("error")) {
            const json& err = parsed["error"];
            if (err.is_string()) {
                return err.get<string>();
            }
            if (err.is_object() && err.contains("message") && err["message"].is_string()) {
                return err["message"].get<string>();
            }
        }
        if (parsed.contains("message") && parsed["message"].is_string()) {
            return parsed["message"].get<string>();
        }
    } catch (...) {
        // Fall through to the HTTP status fallback.
    }

    if (httpStatus > 0) {
        return "HTTP " + to_string(httpStatus);
    }
    return "provider error";
}

bool ExtractJsonPath(const json& root, const string& path, string& outValue) {
    if (path.empty()) {
        return false;
    }

    const json* current = &root;
    size_t pos = 0;

    while (pos < path.length()) {
        size_t dot = path.find('.', pos);
        string segment = (dot == string::npos) ? path.substr(pos) : path.substr(pos, dot - pos);
        pos = (dot == string::npos) ? path.length() : dot + 1;

        if (segment.empty()) {
            return false;
        }

        size_t bracket = segment.find('[');
        string objectKey = bracket == string::npos ? segment : segment.substr(0, bracket);

        if (!objectKey.empty()) {
            if (!current->is_object() || !current->contains(objectKey)) {
                return false;
            }
            current = &(*current)[objectKey];
        }

        while (bracket != string::npos) {
            size_t close = segment.find(']', bracket + 1);
            if (close == string::npos) {
                return false;
            }

            string indexText = segment.substr(bracket + 1, close - bracket - 1);
            if (indexText.empty()) {
                return false;
            }

            int index = atoi(indexText.c_str());
            if (!current->is_array() || index < 0 || static_cast<size_t>(index) >= current->size()) {
                return false;
            }
            current = &(*current)[static_cast<size_t>(index)];
            bracket = segment.find('[', close + 1);
        }
    }

    if (current->is_string()) {
        outValue = current->get<string>();
    } else if (current->is_number() || current->is_boolean()) {
        outValue = current->dump();
    } else {
        return false;
    }

    return !outValue.empty();
}

string IniValue(const map<string, map<string, string>>& ini,
                const string& section,
                const string& key,
                const string& defaultValue = "") {
    auto secIt = ini.find(ToLowerCopy(section));
    if (secIt == ini.end()) {
        return defaultValue;
    }

    auto keyIt = secIt->second.find(ToLowerCopy(key));
    if (keyIt == secIt->second.end()) {
        return defaultValue;
    }

    return keyIt->second;
}

} // namespace

// Global variables
unique_ptr<TranslationClient> g_translator = nullptr;
char g_translation_buffer[4096] = {0};
char g_error_buffer[256] = {0};

TranslationClient::TranslationClient()
    : hSession(nullptr),
      initialized(false),
      provider(TranslationProvider::GOOGLE),
      openaiEndpoint("https://api.openai.com/v1/chat/completions"),
      openaiModel("gpt-4.1-mini"),
      openaiTemperature(0.0),
      customAuthHeader("Authorization"),
      customAuthScheme("Bearer"),
      customResponsePath("translation"),
      lastHttpStatus(0),
      running(false) {
}

TranslationClient::~TranslationClient() {
    Cleanup();
}

bool TranslationClient::StartRuntime() {
    if (initialized) {
        Cleanup();
    }

    LOG_INFO("Initializing translation runtime for provider: " + GetProviderName());
    LOG_INFO("Endpoint: " + GetProviderEndpoint());

    hSession = WinHttpOpen(L"WoWTranslate/2.0",
                           WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                           WINHTTP_NO_PROXY_NAME,
                           WINHTTP_NO_PROXY_BYPASS,
                           0);

    if (!hSession) {
        SetLastError("failed to initialize WinHTTP");
        LOG_ERROR("Failed to initialize WinHTTP session");
        return false;
    }

    if (!WinHttpSetTimeouts(hSession, 5000, 5000, 15000, 30000)) {
        LOG_WARNING("Failed to set WinHTTP timeouts; continuing with defaults");
    }

    running = true;
    workerThread = thread(&TranslationClient::WorkerThreadFunc, this);
    initialized = true;
    SetLastError("");
    LOG_INFO("Translation runtime initialized");
    return true;
}

bool TranslationClient::ConfigureGoogle(const string& apiKey) {
    Cleanup();

    {
        lock_guard<mutex> lock(configMutex);
        provider = TranslationProvider::GOOGLE;
        googleApiKey = apiKey;
        lastHttpStatus = 0;
    }

    if (apiKey.empty()) {
        SetLastError("Google API key is not configured");
        LOG_WARNING("Google provider selected without an API key");
        return false;
    }

    LOG_INFO("Configuring Google provider with key: " + MaskSecret(apiKey));
    return StartRuntime();
}

bool TranslationClient::ConfigureGoogleFree() {
    Cleanup();

    {
        lock_guard<mutex> lock(configMutex);
        provider = TranslationProvider::GOOGLE_FREE;
        lastHttpStatus = 0;
    }

    LOG_INFO("Configuring Google Free provider (no API key)");
    return StartRuntime();
}

bool TranslationClient::ConfigureOpenAICompatible(const string& endpoint,
                                                  const string& apiKey,
                                                  const string& model,
                                                  double temperature) {
    string resolvedEndpoint = endpoint.empty()
        ? "https://api.openai.com/v1/chat/completions"
        : endpoint;
    string resolvedModel = model.empty() ? "gpt-4.1-mini" : model;

    ParsedUrl parsed = ParseUrl(resolvedEndpoint);
    if (!parsed.valid) {
        SetLastError("OpenAI-compatible endpoint must be a valid HTTPS URL");
        return false;
    }

    Cleanup();

    {
        lock_guard<mutex> lock(configMutex);
        provider = TranslationProvider::OPENAI_COMPATIBLE;
        openaiEndpoint = resolvedEndpoint;
        openaiApiKey = apiKey;
        openaiModel = resolvedModel;
        openaiTemperature = temperature;
        lastHttpStatus = 0;
    }

    if (apiKey.empty()) {
        SetLastError("OpenAI-compatible API key is not configured");
        LOG_WARNING("OpenAI-compatible provider selected without an API key");
        return false;
    }

    LOG_INFO("Configuring OpenAI-compatible provider: " + MaskUrl(resolvedEndpoint) +
             ", model=" + resolvedModel);
    return StartRuntime();
}

bool TranslationClient::ConfigureCustomHttp(const string& endpoint,
                                            const string& apiKey,
                                            const string& authHeader,
                                            const string& authScheme,
                                            const string& requestTemplate,
                                            const string& responsePath) {
    ParsedUrl parsed = ParseUrl(endpoint);
    if (!parsed.valid) {
        SetLastError("Custom endpoint must be a valid HTTPS URL");
        return false;
    }

    Cleanup();

    {
        lock_guard<mutex> lock(configMutex);
        provider = TranslationProvider::CUSTOM_HTTP;
        customEndpoint = endpoint;
        customApiKey = apiKey;
        customAuthHeader = authHeader.empty() ? "Authorization" : authHeader;
        customAuthScheme = authScheme;
        customRequestTemplate = requestTemplate.empty()
            ? "{\"text\":\"{text}\",\"source\":\"{source}\",\"target\":\"{target}\"}"
            : requestTemplate;
        customResponsePath = responsePath.empty() ? "translation" : responsePath;
        lastHttpStatus = 0;
    }

    LOG_INFO("Configuring custom HTTP provider: " + MaskUrl(endpoint));
    return StartRuntime();
}

bool TranslationClient::LoadConfigFromIni() {
    string dllPath = GetDllPath();
    if (dllPath.empty()) {
        return false;
    }

    size_t slash = dllPath.find_last_of("\\/");
    string dllDir = slash == string::npos ? "." : dllPath.substr(0, slash);
    string iniPath = dllDir + "\\WoWTranslate.ini";

    ifstream iniFile(iniPath);
    if (!iniFile.is_open()) {
        LOG_INFO("No WoWTranslate.ini found next to DLL");
        return false;
    }

    map<string, map<string, string>> ini;
    string section;
    string line;

    while (getline(iniFile, line)) {
        line = TrimCopy(line);
        if (line.empty() || line[0] == ';' || line[0] == '#') {
            continue;
        }

        if (line.front() == '[' && line.back() == ']') {
            section = ToLowerCopy(TrimCopy(line.substr(1, line.length() - 2)));
            continue;
        }

        size_t eq = line.find('=');
        if (eq == string::npos || section.empty()) {
            continue;
        }

        string key = ToLowerCopy(TrimCopy(line.substr(0, eq)));
        string value = TrimCopy(line.substr(eq + 1));
        ini[section][key] = value;
    }

    string type = ToLowerCopy(IniValue(ini, "provider", "type", "google"));
    LOG_INFO("Loading provider configuration from WoWTranslate.ini: " + type);

    if (type == "google") {
        return ConfigureGoogle(IniValue(ini, "google", "api_key"));
    }

    if (type == "google_free" || type == "googlefree" || type == "free") {
        return ConfigureGoogleFree();
    }

    if (type == "openai" || type == "openai_compatible") {
        string tempText = IniValue(ini, "openai", "temperature", "0");
        double temperature = 0.0;
        try {
            temperature = stod(tempText);
        } catch (...) {
            temperature = 0.0;
        }

        return ConfigureOpenAICompatible(
            IniValue(ini, "openai", "endpoint", "https://api.openai.com/v1/chat/completions"),
            IniValue(ini, "openai", "api_key"),
            IniValue(ini, "openai", "model", "gpt-4.1-mini"),
            temperature);
    }

    if (type == "custom") {
        return ConfigureCustomHttp(
            IniValue(ini, "custom", "endpoint"),
            IniValue(ini, "custom", "api_key"),
            IniValue(ini, "custom", "auth_header", "Authorization"),
            IniValue(ini, "custom", "auth_scheme", "Bearer"),
            IniValue(ini, "custom", "request_template"),
            IniValue(ini, "custom", "response_path", "translation"));
    }

    SetLastError("unknown provider in WoWTranslate.ini: " + type);
    return false;
}

void TranslationClient::Cleanup() {
    if (running) {
        running = false;
        if (workerThread.joinable()) {
            workerThread.join();
        }
    }

    if (hSession) {
        WinHttpCloseHandle(hSession);
        hSession = nullptr;
    }

    {
        lock_guard<mutex> lock(requestMutex);
        queue<AsyncRequest> empty;
        swap(requestQueue, empty);
    }

    {
        lock_guard<mutex> lock(resultMutex);
        queue<AsyncResult> empty;
        swap(resultQueue, empty);
    }

    cache.clear();
    initialized = false;
}

string TranslationClient::GetProviderName() const {
    lock_guard<mutex> lock(configMutex);
    return ProviderName(provider);
}

string TranslationClient::GetProviderEndpoint() const {
    lock_guard<mutex> lock(configMutex);
    if (provider == TranslationProvider::GOOGLE) {
        return "https://translation.googleapis.com/language/translate/v2";
    }
    if (provider == TranslationProvider::GOOGLE_FREE) {
        return "https://translate.googleapis.com/translate_a/single (free, no key)";
    }
    if (provider == TranslationProvider::OPENAI_COMPATIBLE) {
        return MaskUrl(openaiEndpoint);
    }
    return MaskUrl(customEndpoint);
}

string TranslationClient::GetProviderStatusJson() const {
    lock_guard<mutex> lock(configMutex);

    string endpoint;
    if (provider == TranslationProvider::GOOGLE) {
        endpoint = "https://translation.googleapis.com/language/translate/v2";
    } else if (provider == TranslationProvider::GOOGLE_FREE) {
        endpoint = "https://translate.googleapis.com/translate_a/single (free, no key)";
    } else if (provider == TranslationProvider::OPENAI_COMPATIBLE) {
        endpoint = MaskUrl(openaiEndpoint);
    } else {
        endpoint = MaskUrl(customEndpoint);
    }

    bool configured = false;
    if (provider == TranslationProvider::GOOGLE) {
        configured = !googleApiKey.empty();
    } else if (provider == TranslationProvider::GOOGLE_FREE) {
        configured = true;  // no key needed
    } else if (provider == TranslationProvider::OPENAI_COMPATIBLE) {
        configured = !openaiEndpoint.empty() && !openaiApiKey.empty() && !openaiModel.empty();
    } else {
        configured = !customEndpoint.empty() && !customRequestTemplate.empty() && !customResponsePath.empty();
    }

    json status;
    status["provider"] = ProviderName(provider);
    status["configured"] = configured;
    status["ready"] = initialized;
    status["endpoint"] = endpoint;
    status["lastHttpStatus"] = lastHttpStatus;
    return status.dump(-1, ' ', false, json::error_handler_t::replace);
}

string TranslationClient::GetLastError() const {
    lock_guard<mutex> lock(configMutex);
    return lastError;
}

void TranslationClient::SetLastError(const string& error) {
    lock_guard<mutex> lock(configMutex);
    lastError = error;
}

void TranslationClient::SetLastHttpStatus(DWORD status) {
    lock_guard<mutex> lock(configMutex);
    lastHttpStatus = status;
}

string TranslationClient::UrlEncode(const string& text) {
    ostringstream encoded;
    encoded.fill('0');
    encoded << hex;

    for (unsigned char c : text) {
        if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') {
            encoded << static_cast<char>(c);
        } else {
            encoded << uppercase << '%' << setw(2) << static_cast<int>(c) << nouppercase;
        }
    }

    return encoded.str();
}

TranslationClient::ParsedUrl TranslationClient::ParseUrl(const string& url) const {
    ParsedUrl parsed;
    size_t schemeEnd = url.find("://");
    if (schemeEnd == string::npos) {
        return parsed;
    }

    parsed.scheme = ToLowerCopy(url.substr(0, schemeEnd));
    if (parsed.scheme != "https") {
        return parsed;
    }

    string remainder = url.substr(schemeEnd + 3);
    size_t pathStart = remainder.find_first_of("/?");
    string hostPort = pathStart == string::npos ? remainder : remainder.substr(0, pathStart);
    if (pathStart == string::npos) {
        parsed.pathAndQuery = "/";
    } else if (remainder[pathStart] == '?') {
        parsed.pathAndQuery = "/" + remainder.substr(pathStart);
    } else {
        parsed.pathAndQuery = remainder.substr(pathStart);
    }

    if (hostPort.empty()) {
        return parsed;
    }

    size_t colon = hostPort.rfind(':');
    if (colon != string::npos && colon + 1 < hostPort.length()) {
        string portText = hostPort.substr(colon + 1);
        bool allDigits = true;
        for (char ch : portText) {
            if (!isdigit(static_cast<unsigned char>(ch))) {
                allDigits = false;
                break;
            }
        }

        if (allDigits) {
            parsed.host = hostPort.substr(0, colon);
            parsed.port = atoi(portText.c_str());
        } else {
            parsed.host = hostPort;
            parsed.port = 443;
        }
    } else {
        parsed.host = hostPort;
        parsed.port = 443;
    }

    parsed.valid = !parsed.host.empty() && parsed.port > 0;
    return parsed;
}

string TranslationClient::HttpsJsonRequest(const ParsedUrl& url,
                                           const string& postData,
                                           const vector<pair<string, string>>& headers,
                                           DWORD& statusCode,
                                           bool useGet) {
    statusCode = 0;

    if (!hSession || !url.valid) {
        SetLastError("HTTP runtime is not ready");
        return "";
    }

    wstring wHost = ToWide(url.host);
    HINTERNET hConnect = WinHttpConnect(hSession,
                                        wHost.c_str(),
                                        static_cast<INTERNET_PORT>(url.port),
                                        0);
    if (!hConnect) {
        DWORD err = ::GetLastError();
        SetLastError("failed to connect to " + url.host + " (" + to_string(err) + ")");
        LOG_ERROR("WinHttpConnect failed for " + url.host + ": " + to_string(err));
        return "";
    }

    wstring wPath = ToWide(url.pathAndQuery);
    HINTERNET hRequest = WinHttpOpenRequest(hConnect,
                                            useGet ? L"GET" : L"POST",
                                            wPath.c_str(),
                                            nullptr,
                                            WINHTTP_NO_REFERER,
                                            WINHTTP_DEFAULT_ACCEPT_TYPES,
                                            WINHTTP_FLAG_SECURE);

    if (!hRequest) {
        DWORD err = ::GetLastError();
        WinHttpCloseHandle(hConnect);
        SetLastError("failed to open HTTP request (" + to_string(err) + ")");
        LOG_ERROR("WinHttpOpenRequest failed: " + to_string(err));
        return "";
    }

    string headerText = useGet ? "" : "Content-Type: application/json\r\n";
    headerText += "Accept: application/json\r\n";
    for (const auto& header : headers) {
        if (!header.first.empty() && !header.second.empty()) {
            headerText += header.first + ": " + header.second + "\r\n";
        }
    }

    wstring wHeaders = ToWide(headerText);
    if (!WinHttpAddRequestHeaders(hRequest, wHeaders.c_str(), (DWORD)-1, WINHTTP_ADDREQ_FLAG_ADD)) {
        LOG_WARNING("WinHttpAddRequestHeaders failed");
    }

    LOG_DEBUG(string(useGet ? "GET" : "POST") + " https://" + url.host + ":" + to_string(url.port) + MaskUrl(url.pathAndQuery));

    BOOL sent = WinHttpSendRequest(hRequest,
                                   WINHTTP_NO_ADDITIONAL_HEADERS,
                                   0,
                                   (useGet || postData.empty()) ? WINHTTP_NO_REQUEST_DATA : (LPVOID)postData.c_str(),
                                   useGet ? 0 : static_cast<DWORD>(postData.length()),
                                   useGet ? 0 : static_cast<DWORD>(postData.length()),
                                   0);

    string response;
    if (sent && WinHttpReceiveResponse(hRequest, nullptr)) {
        DWORD statusSize = sizeof(statusCode);
        WinHttpQueryHeaders(hRequest,
                            WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                            WINHTTP_HEADER_NAME_BY_INDEX,
                            &statusCode,
                            &statusSize,
                            WINHTTP_NO_HEADER_INDEX);
        SetLastHttpStatus(statusCode);

        DWORD bytesAvailable = 0;
        char buffer[8192];

        while (WinHttpQueryDataAvailable(hRequest, &bytesAvailable) && bytesAvailable > 0) {
            DWORD bytesRead = 0;
            DWORD bytesToRead = std::min(bytesAvailable, static_cast<DWORD>(sizeof(buffer)));

            if (!WinHttpReadData(hRequest, buffer, bytesToRead, &bytesRead) || bytesRead == 0) {
                break;
            }

            response.append(buffer, bytesRead);
        }
    } else {
        DWORD err = ::GetLastError();
        SetLastError("HTTP request failed (" + to_string(err) + ")");
        LOG_ERROR("HTTP request failed with WinHTTP error: " + to_string(err));
    }

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    return response;
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

TranslationResult TranslationClient::TranslateWithGoogle(const string& text,
                                                         string& result,
                                                         const string& sourceLang,
                                                         const string& targetLang) {
    string key;
    {
        lock_guard<mutex> lock(configMutex);
        key = googleApiKey;
    }

    if (key.empty()) {
        result = "Google API key is not configured";
        SetLastError(result);
        return TranslationResult::INVALID_PARAMS;
    }

    ParsedUrl url = ParseUrl("https://translation.googleapis.com/language/translate/v2?key=" + UrlEncode(key));

    json body;
    body["q"] = text;
    if (!sourceLang.empty() && sourceLang != "auto") {
        body["source"] = sourceLang;
    }
    body["target"] = targetLang;
    body["format"] = "text";

    DWORD status = 0;
    string response = HttpsJsonRequest(url, body.dump(-1, ' ', false, json::error_handler_t::replace), {}, status);
    if (response.empty() && status == 0) {
        result = GetLastError().empty() ? "network error" : GetLastError();
        return TranslationResult::NETWORK_ERROR;
    }

    try {
        json parsed = json::parse(response);
        if (status >= 400 || parsed.contains("error")) {
            result = JsonErrorMessage(parsed, status);
            SetLastError(result);
            LOG_ERROR("Google API error: " + result);
            return TranslationResult::API_ERROR;
        }

        string translated;
        if (!ExtractJsonPath(parsed, "data.translations[0].translatedText", translated)) {
            result = "Google response did not include data.translations[0].translatedText";
            SetLastError(result);
            return TranslationResult::API_ERROR;
        }

        result = BasicHtmlDecode(translated);
        SetLastError("");
        return TranslationResult::SUCCESS;
    } catch (const exception& e) {
        result = string("failed to parse Google response: ") + e.what();
        SetLastError(result);
        return TranslationResult::API_ERROR;
    }
}

TranslationResult TranslationClient::TranslateWithGoogleFree(const string& text,
                                                             string& result,
                                                             const string& sourceLang,
                                                             const string& targetLang) {
    string sl = (sourceLang.empty() || sourceLang == "auto") ? "auto" : sourceLang;

    ParsedUrl url = ParseUrl("https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=" +
                             UrlEncode(sl) + "&tl=" + UrlEncode(targetLang) + "&q=" + UrlEncode(text));

    DWORD status = 0;
    string response = HttpsJsonRequest(url, "", {}, status, true /* GET */);

    if (status == 429) {
        result = "rate limited by the free Google endpoint; wait a moment or switch to a keyed provider (/wt provider google)";
        SetLastError(result);
        LOG_WARNING("Google Free endpoint returned HTTP 429");
        return TranslationResult::API_ERROR;
    }

    if (response.empty()) {
        result = GetLastError().empty() ? "network error" : GetLastError();
        return TranslationResult::NETWORK_ERROR;
    }

    if (status >= 400) {
        result = "free endpoint HTTP " + to_string(status);
        SetLastError(result);
        LOG_ERROR("Google Free endpoint error: " + result);
        return TranslationResult::API_ERROR;
    }

    string translated;
    string parseError;
    if (!ParseGtxResponse(response, translated, parseError)) {
        result = parseError;
        SetLastError(result);
        LOG_ERROR("Google Free parse failure: " + parseError);
        return TranslationResult::API_ERROR;
    }

    result = BasicHtmlDecode(translated);
    SetLastError("");
    return TranslationResult::SUCCESS;
}

TranslationResult TranslationClient::TranslateWithOpenAI(const string& text,
                                                         string& result,
                                                         const string& sourceLang,
                                                         const string& targetLang) {
    string endpoint;
    string apiKey;
    string model;
    double temperature = 0.0;

    {
        lock_guard<mutex> lock(configMutex);
        endpoint = openaiEndpoint;
        apiKey = openaiApiKey;
        model = openaiModel;
        temperature = openaiTemperature;
    }

    if (apiKey.empty()) {
        result = "OpenAI-compatible API key is not configured";
        SetLastError(result);
        return TranslationResult::INVALID_PARAMS;
    }

    ParsedUrl url = ParseUrl(endpoint);
    if (!url.valid) {
        result = "OpenAI-compatible endpoint must be a valid HTTPS URL";
        SetLastError(result);
        return TranslationResult::INVALID_PARAMS;
    }

    json body;
    body["model"] = model;
    body["temperature"] = temperature;
    body["messages"] = json::array({
        {
            {"role", "system"},
            {"content", "Translate only. Preserve URLs and placeholders exactly. Return only the translated text; no commentary."}
        },
        {
            {"role", "user"},
            {"content", "Source language: " + sourceLang + "\nTarget language: " + targetLang + "\nText:\n" + text}
        }
    });

    vector<pair<string, string>> headers;
    headers.push_back({"Authorization", "Bearer " + apiKey});

    DWORD status = 0;
    string response = HttpsJsonRequest(url, body.dump(-1, ' ', false, json::error_handler_t::replace), headers, status);
    if (response.empty() && status == 0) {
        result = GetLastError().empty() ? "network error" : GetLastError();
        return TranslationResult::NETWORK_ERROR;
    }

    try {
        json parsed = json::parse(response);
        if (status >= 400 || parsed.contains("error")) {
            result = JsonErrorMessage(parsed, status);
            SetLastError(result);
            LOG_ERROR("OpenAI-compatible provider error: " + result);
            return TranslationResult::API_ERROR;
        }

        if (!ExtractJsonPath(parsed, "choices[0].message.content", result)) {
            result = "OpenAI-compatible response did not include choices[0].message.content";
            SetLastError(result);
            return TranslationResult::API_ERROR;
        }

        result = TrimCopy(result);
        SetLastError("");
        return TranslationResult::SUCCESS;
    } catch (const exception& e) {
        result = string("failed to parse OpenAI-compatible response: ") + e.what();
        SetLastError(result);
        return TranslationResult::API_ERROR;
    }
}

TranslationResult TranslationClient::TranslateWithCustom(const string& text,
                                                         string& result,
                                                         const string& sourceLang,
                                                         const string& targetLang) {
    string endpoint;
    string apiKey;
    string authHeader;
    string authScheme;
    string requestTemplate;
    string responsePath;

    {
        lock_guard<mutex> lock(configMutex);
        endpoint = customEndpoint;
        apiKey = customApiKey;
        authHeader = customAuthHeader;
        authScheme = customAuthScheme;
        requestTemplate = customRequestTemplate;
        responsePath = customResponsePath;
    }

    ParsedUrl url = ParseUrl(endpoint);
    if (!url.valid) {
        result = "Custom endpoint must be a valid HTTPS URL";
        SetLastError(result);
        return TranslationResult::INVALID_PARAMS;
    }

    string body = requestTemplate.empty()
        ? "{\"text\":\"{text}\",\"source\":\"{source}\",\"target\":\"{target}\"}"
        : requestTemplate;
    ReplaceAll(body, "{text}", JsonTemplateEscape(text));
    ReplaceAll(body, "{source}", JsonTemplateEscape(sourceLang));
    ReplaceAll(body, "{target}", JsonTemplateEscape(targetLang));

    vector<pair<string, string>> headers;
    if (!apiKey.empty() && !authHeader.empty()) {
        string headerValue;
        if (authScheme.empty() || ToLowerCopy(authScheme) == "none") {
            headerValue = apiKey;
        } else {
            headerValue = authScheme + " " + apiKey;
        }
        headers.push_back({authHeader, headerValue});
    }

    DWORD status = 0;
    string response = HttpsJsonRequest(url, body, headers, status);
    if (response.empty() && status == 0) {
        result = GetLastError().empty() ? "network error" : GetLastError();
        return TranslationResult::NETWORK_ERROR;
    }

    try {
        json parsed = json::parse(response);
        if (status >= 400 || parsed.contains("error")) {
            result = JsonErrorMessage(parsed, status);
            SetLastError(result);
            LOG_ERROR("Custom provider error: " + result);
            return TranslationResult::API_ERROR;
        }

        if (!ExtractJsonPath(parsed, responsePath, result)) {
            result = "Custom response did not include path: " + responsePath;
            SetLastError(result);
            return TranslationResult::API_ERROR;
        }

        result = TrimCopy(result);
        SetLastError("");
        return TranslationResult::SUCCESS;
    } catch (const exception& e) {
        result = string("failed to parse custom response: ") + e.what();
        SetLastError(result);
        return TranslationResult::API_ERROR;
    }
}

TranslationResult TranslationClient::TranslateText(const string& text,
                                                   string& result,
                                                   const string& sourceLang,
                                                   const string& targetLang) {
    if (!initialized) {
        result = "translator not initialized";
        SetLastError(result);
        LOG_ERROR(result);
        return TranslationResult::INVALID_PARAMS;
    }

    if (text.empty()) {
        result = "empty text";
        SetLastError(result);
        return TranslationResult::INVALID_PARAMS;
    }

    TranslationProvider activeProvider;
    {
        lock_guard<mutex> lock(configMutex);
        activeProvider = provider;
    }

    string cacheKey = to_string(static_cast<int>(activeProvider)) + ":" +
                      sourceLang + "->" + targetLang + ":" + text;
    auto cacheIt = cache.find(cacheKey);
    if (cacheIt != cache.end() && (GetTickCount() - cacheIt->second.timestamp) < CACHE_EXPIRY_MS) {
        result = cacheIt->second.translation;
        LOG_DEBUG("DLL cache hit for translation request");
        return TranslationResult::SUCCESS;
    }

    CleanExpiredCache();

    TranslationResult tr = TranslationResult::API_ERROR;
    if (activeProvider == TranslationProvider::GOOGLE) {
        tr = TranslateWithGoogle(text, result, sourceLang, targetLang);
    } else if (activeProvider == TranslationProvider::GOOGLE_FREE) {
        tr = TranslateWithGoogleFree(text, result, sourceLang, targetLang);
    } else if (activeProvider == TranslationProvider::OPENAI_COMPATIBLE) {
        tr = TranslateWithOpenAI(text, result, sourceLang, targetLang);
    } else {
        tr = TranslateWithCustom(text, result, sourceLang, targetLang);
    }

    if (tr == TranslationResult::SUCCESS) {
        cache[cacheKey] = CacheEntry(result);
        LOG_DEBUG("Translation successful using provider: " + ProviderName(activeProvider));
    }

    return tr;
}

bool TranslationClient::TranslateAsync(const string& requestId,
                                       const string& text,
                                       const string& sourceLang,
                                       const string& targetLang) {
    if (!initialized || !running) {
        return false;
    }

    lock_guard<mutex> lock(requestMutex);
    requestQueue.push(AsyncRequest(requestId, text, sourceLang, targetLang));
    LOG_DEBUG("Async request queued: " + requestId + " (" + sourceLang + " -> " + targetLang + ")");
    return true;
}

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

size_t TranslationClient::GetPendingCount() {
    lock_guard<mutex> lock(requestMutex);
    return requestQueue.size();
}

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

            // The worker thread must be exception-proof: an uncaught throw
            // here is std::terminate -> the whole game process dies.
            TranslationResult tr;
            try {
                tr = TranslateText(request.text, translation, request.sourceLang, request.targetLang);
            } catch (const std::exception& e) {
                tr = TranslationResult::API_ERROR;
                translation = string("internal error: ") + e.what();
                LOG_ERROR("Exception processing request " + request.requestId + ": " + e.what());
            } catch (...) {
                tr = TranslationResult::API_ERROR;
                translation = "internal error: unknown exception";
                LOG_ERROR("Unknown exception processing request " + request.requestId);
            }
            if (tr != TranslationResult::SUCCESS) {
                switch (tr) {
                    case TranslationResult::NETWORK_ERROR: error = translation.empty() ? "network error" : translation; break;
                    case TranslationResult::API_ERROR: error = translation.empty() ? "API error" : translation; break;
                    case TranslationResult::ENCODING_ERROR: error = "encoding error"; break;
                    case TranslationResult::TIMEOUT_ERROR: error = "timeout"; break;
                    case TranslationResult::INVALID_PARAMS: error = translation.empty() ? "invalid parameters" : translation; break;
                    default: error = "unknown error"; break;
                }
                translation = "";
            }

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
