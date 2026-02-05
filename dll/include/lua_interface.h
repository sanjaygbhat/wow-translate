#pragma once

#include <string>
#include <cstdint>

// Lua C API function pointers (following UnitXP_SP3 pattern)
typedef int(__fastcall* LUA_CFUNCTION)(void* L);
typedef void(__fastcall* LUA_PUSHSTRING)(void* L, const char* s);
typedef void(__fastcall* LUA_PUSHBOOLEAN)(void* L, int boolean_value);
typedef void(__fastcall* LUA_PUSHNUMBER)(void* L, double n);
typedef void(__fastcall* LUA_PUSHNIL)(void* L);
typedef const char* (__fastcall* LUA_TOSTRING)(void* L, int index);
typedef double(__fastcall* LUA_TONUMBER)(void* L, int index);
typedef int(__fastcall* LUA_TOBOOLEAN)(void* L, int index);
typedef int(__fastcall* LUA_GETTOP)(void* L);
typedef int(__fastcall* LUA_ISNUMBER)(void* L, int index);
typedef int(__fastcall* LUA_ISSTRING)(void* L, int index);
typedef void* (__fastcall* GETCONTEXT)(void);

// Main WoWTranslate command handler (internal hook function)
int __fastcall detoured_UnitXP(void* L);

// Lua interface functions
bool InitializeLuaInterface();
void CleanupLuaInterface();

// Helper functions for Lua interaction
void lua_pushstring(void* L, const std::string& str);
void lua_pushboolean(void* L, bool value);
void lua_pushnumber(void* L, double value);
void lua_pushnil(void* L);
std::string lua_tostring(void* L, int index);
double lua_tonumber(void* L, int index);
bool lua_toboolean(void* L, int index);
int lua_gettop(void* L);
bool lua_isnumber(void* L, int index);
bool lua_isstring(void* L, int index);
void* GetLuaContext();
