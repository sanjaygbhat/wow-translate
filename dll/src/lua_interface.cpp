// lua_interface.cpp - Lua interface for WoWTranslate
// Handles DLL communication and async translation via UnitXP hook

#include <windows.h>
#include <string>
#include <sstream>
#include <vector>

#ifdef MINHOOK_AVAILABLE
#include "MinHook.h"
#endif

#include "../include/lua_interface.h"
#include "../include/translator_core.h"
#include "../include/logging.h"
#include "../include/utils.h"

using namespace std;

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

// Memory addresses for Turtle WoW Lua functions (from working UnitXP_SP3)
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

// Helper functions
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

// Main WoWTranslate command handler
// Commands:
//   UnitXP("WoWTranslate", "ping") -> "pong"
//   UnitXP("WoWTranslate", "setkey", apiKey) -> "ok" or error
//   UnitXP("WoWTranslate", "translate_async", requestId, text) -> "ok" or error
//   UnitXP("WoWTranslate", "poll") -> "requestId|translation|error|credits" or ""
//   UnitXP("WoWTranslate", "status") -> status string
//   UnitXP("WoWTranslate", "credits") -> get credits remaining
int __fastcall detoured_UnitXP(void* L) {
    try {
        if (lua_gettop(L) >= 1) {
            string cmd{ lua_tostring(L, 1) };

            // Check if this is a WoWTranslate command
            if (cmd == "WoWTranslate") {
                LOG_DEBUG("WoWTranslate command intercepted");

                if (lua_gettop(L) >= 2) {
                    string subcmd{ lua_tostring(L, 2) };

                    // PING - Check if DLL is loaded
                    if (subcmd == "ping") {
                        lua_pushstring(L, "pong");
                        LOG_DEBUG("Ping -> Pong");
                        return 1;
                    }

                    // VERSION - Get version string
                    else if (subcmd == "version") {
                        lua_pushstring(L, "WoWTranslate v0.2 - Multi-language Translation via Proxy Server");
                        return 1;
                    }

                    // STATUS - Get current status
                    else if (subcmd == "status") {
                        string status = "WoWTranslate Status: DLL Active, Translator ";
                        status += (g_translator && g_translator->IsInitialized()) ? "Ready" : "Not Ready";
                        if (g_translator) {
                            status += ", Server: " + g_translator->GetServerInfo();
                            status += ", Pending: " + to_string(g_translator->GetPendingCount());
                            double credits = g_translator->GetCreditsRemaining();
                            if (credits >= 0) {
                                status += ", Credits: " + to_string(static_cast<int>(credits)) + " cents";
                            }
                        }
                        lua_pushstring(L, status);
                        return 1;
                    }

                    // SETKEY - Set the WoWTranslate API key
                    else if (subcmd == "setkey") {
                        if (lua_gettop(L) >= 3) {
                            string apiKey{ lua_tostring(L, 3) };

                            if (g_translator && g_translator->Initialize(apiKey)) {
                                lua_pushstring(L, "ok");
                                LOG_INFO("API key set successfully");
                            } else {
                                lua_pushstring(L, "error|initialization failed");
                                LOG_ERROR("Failed to initialize with API key");
                            }
                            return 1;
                        }
                        lua_pushstring(L, "error|API key required");
                        return 1;
                    }

                    // CREDITS - Get credits remaining
                    else if (subcmd == "credits") {
                        if (g_translator) {
                            double credits = g_translator->GetCreditsRemaining();
                            if (credits >= 0) {
                                lua_pushnumber(L, credits);
                            } else {
                                lua_pushstring(L, "unknown");
                            }
                        } else {
                            lua_pushstring(L, "error|translator not available");
                        }
                        return 1;
                    }

                    // TRANSLATE_ASYNC - Queue async translation request
                    // Args: requestId, text, [sourceLang], [targetLang]
                    // Optional language params default to zh->en for backward compatibility
                    else if (subcmd == "translate_async") {
                        if (lua_gettop(L) >= 4) {
                            string requestId{ lua_tostring(L, 3) };
                            string text{ lua_tostring(L, 4) };

                            // Optional language parameters (default zh->en for backward compat)
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
                        lua_pushstring(L, "error|requestId and text required");
                        return 1;
                    }

                    // POLL - Poll for completed translation
                    // Returns: "requestId|translation|error|credits" or ""
                    else if (subcmd == "poll") {
                        if (!g_translator) {
                            lua_pushstring(L, "");
                            return 1;
                        }

                        string requestId, translation, error;
                        if (g_translator->PollResult(requestId, translation, error)) {
                            // Format: requestId|translation|error|credits
                            double credits = g_translator->GetCreditsRemaining();
                            string creditsStr = (credits >= 0) ? to_string(static_cast<int>(credits)) : "";
                            string result = requestId + "|" + translation + "|" + error + "|" + creditsStr;
                            lua_pushstring(L, result);
                            LOG_DEBUG("Poll returned: " + requestId + " (credits: " + creditsStr + ")");
                        } else {
                            // No results available
                            lua_pushstring(L, "");
                        }
                        return 1;
                    }

                    // TRANSLATE (synchronous) - For testing
                    // Args: text, [sourceLang], [targetLang]
                    else if (subcmd == "translate") {
                        if (lua_gettop(L) >= 3) {
                            string text{ lua_tostring(L, 3) };

                            // Optional language parameters (default zh->en for backward compat)
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
                                LOG_DEBUG("Sync translation: " + text + " -> " + result);
                            } else {
                                string error = "error|";
                                switch (tr) {
                                    case TranslationResult::NETWORK_ERROR: error += "network error"; break;
                                    case TranslationResult::API_ERROR: error += "API error"; break;
                                    case TranslationResult::ENCODING_ERROR: error += "encoding error"; break;
                                    case TranslationResult::TIMEOUT_ERROR: error += "timeout"; break;
                                    case TranslationResult::INVALID_PARAMS: error += "invalid parameters"; break;
                                    default: error += "unknown error"; break;
                                }
                                lua_pushstring(L, error);
                            }
                            return 1;
                        }
                        lua_pushstring(L, "error|text required");
                        return 1;
                    }

                    else {
                        string error = "error|unknown command: " + subcmd;
                        lua_pushstring(L, error);
                        return 1;
                    }
                } else {
                    lua_pushstring(L, "error|no subcommand specified");
                    return 1;
                }
            }
        }

        // Not our command - call original UnitXP if available
        if (p_original_UnitXP) {
            return p_original_UnitXP(L);
        }

        // Fallback - return 0 if no original function
        return 0;

    } catch (const exception& e) {
        string error = "WoWTranslate Exception: " + string(e.what());
        LOG_ERROR(error);
        lua_pushstring(L, ("error|" + string(e.what())).c_str());
        return 1;
    } catch (...) {
        string error = "WoWTranslate Unknown Exception";
        LOG_ERROR(error);
        lua_pushstring(L, "error|unknown exception");
        return 1;
    }
}

// Initialize the Lua interface by hooking UnitXP
bool InitializeLuaInterface() {
    if (g_initialized) {
        LOG_WARNING("Lua interface already initialized");
        return true;
    }

    LOG_INFO("Initializing WoWTranslate Lua interface...");

#ifdef MINHOOK_AVAILABLE
    // Initialize MinHook
    if (MH_Initialize() != MH_OK) {
        LOG_ERROR("Failed to initialize MinHook");
        return false;
    }

    // Hook the UnitXP function with our handler
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

// Cleanup the Lua interface
void CleanupLuaInterface() {
    if (!g_initialized) {
        return;
    }

    LOG_INFO("Cleaning up WoWTranslate Lua interface...");

#ifdef MINHOOK_AVAILABLE
    // Disable and remove hook
    MH_DisableHook(reinterpret_cast<LPVOID>(p_UnitXP));
    MH_RemoveHook(reinterpret_cast<LPVOID>(p_UnitXP));
    MH_Uninitialize();
#endif

    g_initialized = false;
    LOG_INFO("WoWTranslate Lua interface cleanup complete");
}
