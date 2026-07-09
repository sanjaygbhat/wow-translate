// lua_interface.cpp - Lua interface for WoWTranslate
// Handles DLL communication and async translation via UnitXP hook.

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
#include <memory>
#include <string>

#ifdef _MSC_VER
#pragma warning(push, 0)
#endif
#include "json.hpp"
#ifdef _MSC_VER
#pragma warning(pop)
#endif

#ifdef MINHOOK_AVAILABLE
#include "MinHook.h"
#endif

#include "../include/lua_interface.h"
#include "../include/translator_core.h"
#include "../include/logging.h"

using namespace std;
using json = nlohmann::json;

// Lua function pointer types (following UnitXP_SP3 exactly)
typedef void* (__fastcall* GETCONTEXT)(void);
typedef void (__fastcall* LUA_PUSHSTRING)(void* L, const char* s);
typedef void (__fastcall* LUA_PUSHBOOLEAN)(void* L, int boolean_value);
typedef void (__fastcall* LUA_PUSHNUMBER)(void* L, double n);
typedef void (__fastcall* LUA_PUSHNIL)(void* L);
typedef const char* (__fastcall* LUA_TOSTRING)(void* L, int index);
typedef double (__fastcall* LUA_TONUMBER)(void* L, int index);
typedef int (__fastcall* LUA_TOBOOLEAN)(void* L, int index);
typedef int (__fastcall* LUA_GETTOP)(void* L);
typedef int (__fastcall* LUA_ISNUMBER)(void* L, int index);
typedef int (__fastcall* LUA_ISSTRING)(void* L, int index);

// Memory addresses for WoW 1.12 Lua functions (from working UnitXP_SP3)
static auto p_GetContext = reinterpret_cast<GETCONTEXT>(0x7040D0);
static auto p_lua_pushstring = reinterpret_cast<LUA_PUSHSTRING>(0x006F3890);
static auto p_lua_pushboolean = reinterpret_cast<LUA_PUSHBOOLEAN>(0x006F39F0);
static auto p_lua_pushnumber = reinterpret_cast<LUA_PUSHNUMBER>(0x006F3810);
static auto p_lua_pushnil = reinterpret_cast<LUA_PUSHNIL>(0x006F37F0);
static auto p_lua_tostring = reinterpret_cast<LUA_TOSTRING>(0x006F3690);
static auto p_lua_tonumber = reinterpret_cast<LUA_TONUMBER>(0x006F3620);
static auto p_lua_toboolean = reinterpret_cast<LUA_TOBOOLEAN>(0x6F3660);
static auto p_lua_gettop = reinterpret_cast<LUA_GETTOP>(0x006F3070);
static auto p_lua_isnumber = reinterpret_cast<LUA_ISNUMBER>(0x006F34D0);
static auto p_lua_isstring = reinterpret_cast<LUA_ISSTRING>(0x6F3510);

// Hook target - we hook the UnitXP function
static auto p_UnitXP = reinterpret_cast<LUA_CFUNCTION>(0x517350);
static LUA_CFUNCTION p_original_UnitXP = nullptr;

// State tracking
static bool g_initialized = false;

static TranslationClient* EnsureTranslator() {
    if (!g_translator) {
        g_translator = make_unique<TranslationClient>();
    }
    return g_translator.get();
}

void* GetLuaContext() {
    void* result = p_GetContext();
    if (!result) {
        LOG_ERROR("Lua context is NULL");
    }
    return result;
}

void lua_pushstring(void* L, const string& str) {
    if (p_lua_pushstring && L) {
        p_lua_pushstring(L, str.c_str());
    }
}

void lua_pushboolean(void* L, bool value) {
    if (p_lua_pushboolean && L) {
        p_lua_pushboolean(L, value ? 1 : 0);
    }
}

void lua_pushnumber(void* L, double value) {
    if (p_lua_pushnumber && L) {
        p_lua_pushnumber(L, value);
    }
}

void lua_pushnil(void* L) {
    if (p_lua_pushnil && L) {
        p_lua_pushnil(L);
    }
}

string lua_tostring(void* L, int index) {
    if (!p_lua_tostring || !L) return "";
    const char* ptr = p_lua_tostring(L, index);
    return ptr ? string(ptr) : "";
}

double lua_tonumber(void* L, int index) {
    if (!p_lua_tonumber || !L) return 0.0;
    return p_lua_tonumber(L, index);
}

bool lua_toboolean(void* L, int index) {
    if (!p_lua_toboolean || !L) return false;
    return p_lua_toboolean(L, index) != 0;
}

int lua_gettop(void* L) {
    if (!p_lua_gettop || !L) return 0;
    return p_lua_gettop(L);
}

bool lua_isnumber(void* L, int index) {
    if (!p_lua_isnumber || !L) return false;
    return p_lua_isnumber(L, index) != 0;
}

bool lua_isstring(void* L, int index) {
    if (!p_lua_isstring || !L) return false;
    return p_lua_isstring(L, index) != 0;
}

static void PushConfigureResult(void* L, bool ok, const string& fallbackError) {
    if (ok) {
        lua_pushstring(L, "ok");
        return;
    }

    string error = fallbackError;
    if (g_translator && !g_translator->GetLastError().empty()) {
        error = g_translator->GetLastError();
    }
    lua_pushstring(L, "error|" + error);
}

// Main WoWTranslate command handler
// Commands:
//   UnitXP("WoWTranslate", "ping") -> "pong"
//   UnitXP("WoWTranslate", "version") -> version string
//   UnitXP("WoWTranslate", "configure_google", apiKey) -> "ok" or "error|message"
//   UnitXP("WoWTranslate", "configure_openai", endpoint, apiKey, model, temperature) -> "ok" or error
//   UnitXP("WoWTranslate", "configure_custom", endpoint, apiKey, authHeader, authScheme, template, path) -> "ok" or error
//   UnitXP("WoWTranslate", "provider_status") -> JSON status string
//   UnitXP("WoWTranslate", "last_error") -> last provider error
//   UnitXP("WoWTranslate", "translate_async", requestId, text, sourceLang, targetLang) -> "ok" or error
//   UnitXP("WoWTranslate", "poll") -> JSON result string or ""
//   UnitXP("WoWTranslate", "translate", text, sourceLang, targetLang) -> translation or "error|message"
//   UnitXP("WoWTranslate", "status") -> diagnostic status string
int __fastcall detoured_UnitXP(void* L) {
    try {
        if (lua_gettop(L) >= 1) {
            string cmd{ lua_tostring(L, 1) };

            if (cmd == "WoWTranslate") {
                if (lua_gettop(L) < 2) {
                    lua_pushstring(L, "error|no subcommand specified");
                    return 1;
                }

                string subcmd{ lua_tostring(L, 2) };

                if (subcmd == "ping") {
                    lua_pushstring(L, "pong");
                    return 1;
                }

                if (subcmd == "version") {
                    lua_pushstring(L, "WoWTranslate v2.0 - Direct Provider Translation");
                    return 1;
                }

                if (subcmd == "configure_google") {
                    if (lua_gettop(L) < 3) {
                        lua_pushstring(L, "error|Google API key required");
                        return 1;
                    }

                    string apiKey{ lua_tostring(L, 3) };
                    bool ok = EnsureTranslator()->ConfigureGoogle(apiKey);
                    PushConfigureResult(L, ok, "failed to configure Google provider");
                    return 1;
                }

                if (subcmd == "configure_openai") {
                    if (lua_gettop(L) < 5) {
                        lua_pushstring(L, "error|endpoint, API key, and model required");
                        return 1;
                    }

                    string endpoint{ lua_tostring(L, 3) };
                    string apiKey{ lua_tostring(L, 4) };
                    string model{ lua_tostring(L, 5) };
                    double temperature = 0.0;
                    if (lua_gettop(L) >= 6 && lua_isnumber(L, 6)) {
                        temperature = lua_tonumber(L, 6);
                    } else if (lua_gettop(L) >= 6) {
                        try {
                            temperature = stod(lua_tostring(L, 6));
                        } catch (...) {
                            temperature = 0.0;
                        }
                    }

                    bool ok = EnsureTranslator()->ConfigureOpenAICompatible(endpoint, apiKey, model, temperature);
                    PushConfigureResult(L, ok, "failed to configure OpenAI-compatible provider");
                    return 1;
                }

                if (subcmd == "configure_custom") {
                    if (lua_gettop(L) < 3) {
                        lua_pushstring(L, "error|custom endpoint required");
                        return 1;
                    }

                    string endpoint{ lua_tostring(L, 3) };
                    string apiKey = lua_gettop(L) >= 4 ? lua_tostring(L, 4) : "";
                    string authHeader = lua_gettop(L) >= 5 ? lua_tostring(L, 5) : "Authorization";
                    string authScheme = lua_gettop(L) >= 6 ? lua_tostring(L, 6) : "Bearer";
                    string requestTemplate = lua_gettop(L) >= 7 ? lua_tostring(L, 7) : "";
                    string responsePath = lua_gettop(L) >= 8 ? lua_tostring(L, 8) : "translation";

                    bool ok = EnsureTranslator()->ConfigureCustomHttp(
                        endpoint, apiKey, authHeader, authScheme, requestTemplate, responsePath);
                    PushConfigureResult(L, ok, "failed to configure custom provider");
                    return 1;
                }

                if (subcmd == "provider_status") {
                    if (!g_translator) {
                        lua_pushstring(L, "{\"provider\":\"google\",\"configured\":false,\"ready\":false,\"endpoint\":\"\",\"lastHttpStatus\":0}");
                    } else {
                        lua_pushstring(L, g_translator->GetProviderStatusJson());
                    }
                    return 1;
                }

                if (subcmd == "last_error") {
                    lua_pushstring(L, g_translator ? g_translator->GetLastError() : "");
                    return 1;
                }

                if (subcmd == "status") {
                    string status = "WoWTranslate Status: DLL Active, Translator ";
                    status += (g_translator && g_translator->IsInitialized()) ? "Ready" : "Not Ready";
                    if (g_translator) {
                        status += ", Provider: " + g_translator->GetProviderName();
                        status += ", Endpoint: " + g_translator->GetProviderEndpoint();
                        status += ", Pending: " + to_string(g_translator->GetPendingCount());
                        if (g_translator->GetLastHttpStatus() > 0) {
                            status += ", HTTP: " + to_string(g_translator->GetLastHttpStatus());
                        }
                        if (!g_translator->GetLastError().empty()) {
                            status += ", Last error: " + g_translator->GetLastError();
                        }
                    }
                    lua_pushstring(L, status);
                    return 1;
                }

                if (subcmd == "translate_async") {
                    if (lua_gettop(L) < 4) {
                        lua_pushstring(L, "error|requestId and text required");
                        return 1;
                    }

                    string requestId{ lua_tostring(L, 3) };
                    string text{ lua_tostring(L, 4) };

                    string sourceLang = "zh";
                    string targetLang = "en";
                    if (lua_gettop(L) >= 6) {
                        sourceLang = lua_tostring(L, 5);
                        targetLang = lua_tostring(L, 6);
                    }

                    if (!g_translator || !g_translator->IsInitialized()) {
                        lua_pushstring(L, "error|translator not initialized");
                        return 1;
                    }

                    if (text.empty()) {
                        lua_pushstring(L, "error|empty text");
                        return 1;
                    }

                    if (g_translator->TranslateAsync(requestId, text, sourceLang, targetLang)) {
                        lua_pushstring(L, "ok");
                        LOG_DEBUG("Async translation queued: " + requestId + " (" + sourceLang + " -> " + targetLang + ")");
                    } else {
                        lua_pushstring(L, "error|failed to queue request");
                    }
                    return 1;
                }

                if (subcmd == "poll") {
                    if (!g_translator) {
                        lua_pushstring(L, "");
                        return 1;
                    }

                    string requestId, translation, error;
                    if (g_translator->PollResult(requestId, translation, error)) {
                        json result;
                        result["id"] = requestId;
                        result["translation"] = translation;
                        result["error"] = error;
                        lua_pushstring(L, result.dump());
                        LOG_DEBUG("Poll returned: " + requestId);
                    } else {
                        lua_pushstring(L, "");
                    }
                    return 1;
                }

                if (subcmd == "translate") {
                    if (lua_gettop(L) < 3) {
                        lua_pushstring(L, "error|text required");
                        return 1;
                    }

                    string text{ lua_tostring(L, 3) };
                    string sourceLang = "zh";
                    string targetLang = "en";
                    if (lua_gettop(L) >= 5) {
                        sourceLang = lua_tostring(L, 4);
                        targetLang = lua_tostring(L, 5);
                    }

                    if (!g_translator || !g_translator->IsInitialized()) {
                        lua_pushstring(L, "error|translator not initialized");
                        return 1;
                    }

                    string result;
                    TranslationResult tr = g_translator->TranslateText(text, result, sourceLang, targetLang);
                    if (tr == TranslationResult::SUCCESS) {
                        lua_pushstring(L, result);
                    } else {
                        lua_pushstring(L, "error|" + (result.empty() ? "translation failed" : result));
                    }
                    return 1;
                }

                lua_pushstring(L, "error|unknown command: " + subcmd);
                return 1;
            }
        }

        if (p_original_UnitXP) {
            return p_original_UnitXP(L);
        }

        return 0;

    } catch (const exception& e) {
        string error = "WoWTranslate Exception: " + string(e.what());
        LOG_ERROR(error);
        lua_pushstring(L, "error|" + string(e.what()));
        return 1;
    } catch (...) {
        LOG_ERROR("WoWTranslate Unknown Exception");
        lua_pushstring(L, "error|unknown exception");
        return 1;
    }
}

bool InitializeLuaInterface() {
    if (g_initialized) {
        LOG_WARNING("Lua interface already initialized");
        return true;
    }

    LOG_INFO("Initializing WoWTranslate Lua interface...");

#ifdef MINHOOK_AVAILABLE
    if (MH_Initialize() != MH_OK) {
        LOG_ERROR("Failed to initialize MinHook");
        return false;
    }

    if (MH_CreateHook(reinterpret_cast<LPVOID>(p_UnitXP),
                      reinterpret_cast<LPVOID>(detoured_UnitXP),
                      reinterpret_cast<LPVOID*>(&p_original_UnitXP)) != MH_OK) {
        LOG_ERROR("Failed to create hook for UnitXP function");
        return false;
    }

    if (MH_EnableHook(reinterpret_cast<LPVOID>(p_UnitXP)) != MH_OK) {
        LOG_ERROR("Failed to enable hook for UnitXP function");
        return false;
    }

    LOG_INFO("Successfully hooked UnitXP function");
#else
    LOG_WARNING("MinHook not available - hooks not installed");
#endif

    g_initialized = true;
    LOG_INFO("WoWTranslate Lua interface initialization complete");
    return true;
}

void CleanupLuaInterface() {
    if (!g_initialized) {
        return;
    }

    LOG_INFO("Cleaning up WoWTranslate Lua interface...");

#ifdef MINHOOK_AVAILABLE
    MH_DisableHook(reinterpret_cast<LPVOID>(p_UnitXP));
    MH_RemoveHook(reinterpret_cast<LPVOID>(p_UnitXP));
    MH_Uninitialize();
#endif

    g_initialized = false;
    LOG_INFO("WoWTranslate Lua interface cleanup complete");
}
