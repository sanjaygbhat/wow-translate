#pragma once

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
#include <winhttp.h>
#include <string>
#include <unordered_map>
#include <memory>
#include <queue>
#include <mutex>
#include <thread>
#include <atomic>
#include <vector>
#include <utility>

// Translation provider mode
enum class TranslationProvider {
    GOOGLE = 0,
    OPENAI_COMPATIBLE = 1,
    CUSTOM_HTTP = 2
};

// Translation result codes
enum class TranslationResult {
    SUCCESS = 0,
    NETWORK_ERROR = 1,
    API_ERROR = 2,
    ENCODING_ERROR = 3,
    TIMEOUT_ERROR = 4,
    INVALID_PARAMS = 5,
    PENDING = 6
};

// Async translation request
struct AsyncRequest {
    std::string requestId;
    std::string text;
    std::string sourceLang;
    std::string targetLang;
    DWORD timestamp;

    AsyncRequest() : sourceLang("zh"), targetLang("en"), timestamp(0) {}
    AsyncRequest(const std::string& id, const std::string& t,
                 const std::string& src = "zh", const std::string& tgt = "en")
        : requestId(id), text(t), sourceLang(src), targetLang(tgt), timestamp(GetTickCount()) {}
};

// Async translation result
struct AsyncResult {
    std::string requestId;
    std::string translation;
    std::string error;
    bool ready;

    AsyncResult() : ready(false) {}
    AsyncResult(const std::string& id, const std::string& trans, const std::string& err)
        : requestId(id), translation(trans), error(err), ready(true) {}
};

// Cache entry structure
struct CacheEntry {
    std::string translation;
    DWORD timestamp;

    CacheEntry() : translation(""), timestamp(0) {}
    CacheEntry(const std::string& trans)
        : translation(trans), timestamp(GetTickCount()) {}
};

// Translation client class with async support
class TranslationClient {
private:
    HINTERNET hSession;
    std::unordered_map<std::string, CacheEntry> cache;
    bool initialized;

    // Provider mode
    TranslationProvider provider;
    mutable std::mutex configMutex;

    std::string googleApiKey;

    std::string openaiEndpoint;
    std::string openaiApiKey;
    std::string openaiModel;
    double openaiTemperature;

    std::string customEndpoint;
    std::string customApiKey;
    std::string customAuthHeader;
    std::string customAuthScheme;
    std::string customRequestTemplate;
    std::string customResponsePath;

    std::string lastError;
    DWORD lastHttpStatus;

    // Async translation support
    std::queue<AsyncRequest> requestQueue;
    std::queue<AsyncResult> resultQueue;
    std::mutex requestMutex;
    std::mutex resultMutex;
    std::thread workerThread;
    std::atomic<bool> running;

    static const DWORD CACHE_EXPIRY_MS = 3600000; // 1 hour (DLL cache)
    static const size_t MAX_CACHE_SIZE = 500;

    struct ParsedUrl {
        bool valid;
        std::string scheme;
        std::string host;
        int port;
        std::string pathAndQuery;

        ParsedUrl() : valid(false), port(443), pathAndQuery("/") {}
    };

    // Helper methods
    std::string UrlEncode(const std::string& text);
    ParsedUrl ParseUrl(const std::string& url) const;
    std::string HttpsJsonRequest(const ParsedUrl& url,
                                 const std::string& postData,
                                 const std::vector<std::pair<std::string, std::string>>& headers,
                                 DWORD& statusCode);
    TranslationResult TranslateWithGoogle(const std::string& text, std::string& result,
                                          const std::string& sourceLang, const std::string& targetLang);
    TranslationResult TranslateWithOpenAI(const std::string& text, std::string& result,
                                          const std::string& sourceLang, const std::string& targetLang);
    TranslationResult TranslateWithCustom(const std::string& text, std::string& result,
                                          const std::string& sourceLang, const std::string& targetLang);
    void CleanExpiredCache();
    bool StartRuntime();
    void SetLastError(const std::string& error);
    void SetLastHttpStatus(DWORD status);

    // Worker thread function
    void WorkerThreadFunc();

public:
    TranslationClient();
    ~TranslationClient();

    bool ConfigureGoogle(const std::string& googleApiKey);
    bool ConfigureOpenAICompatible(const std::string& endpoint,
                                   const std::string& apiKey,
                                   const std::string& model,
                                   double temperature = 0.0);
    bool ConfigureCustomHttp(const std::string& endpoint,
                             const std::string& apiKey,
                             const std::string& authHeader,
                             const std::string& authScheme,
                             const std::string& requestTemplate,
                             const std::string& responsePath);
    bool LoadConfigFromIni();
    void Cleanup();
    bool IsInitialized() const { return initialized; }

    // Provider
    TranslationProvider GetProvider() const { return provider; }
    std::string GetProviderName() const;
    std::string GetProviderEndpoint() const;
    std::string GetProviderStatusJson() const;
    std::string GetLastError() const;
    DWORD GetLastHttpStatus() const { return lastHttpStatus; }

    // Synchronous translation with configurable language direction
    TranslationResult TranslateText(const std::string& text, std::string& result,
                                    const std::string& sourceLang = "zh", const std::string& targetLang = "en");

    // Async translation methods with configurable language direction
    bool TranslateAsync(const std::string& requestId, const std::string& text,
                        const std::string& sourceLang = "zh", const std::string& targetLang = "en");
    bool PollResult(std::string& requestId, std::string& translation, std::string& error);
    size_t GetPendingCount();
};

// Global translation instance
extern std::unique_ptr<TranslationClient> g_translator;

// Static buffers for Lua interface
extern char g_translation_buffer[4096];
extern char g_error_buffer[256];
