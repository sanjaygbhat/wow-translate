#pragma once

// Parser for Google's free (unofficial) translate endpoint:
//   GET translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=..&tl=..&q=..
// Response shape (verified live 2026-07-10):
//   [[["Hello World","你好世界",null,null,10]],null,"zh-CN",...]
//   [[["Seg one. ","原文一。",...],["Seg two","原文二",...]],null,"zh-CN",...]
// The translation is the concatenation of [0][i][0] over all segments i.
//
// Kept as a pure, standalone function so the host-side unit test
// (tests/gtx_parser_test.cpp) can compile it without WinHTTP/Windows.

#include <string>
#include "../third_party/json.hpp"

inline bool ParseGtxResponse(const std::string& body,
                             std::string& translation,
                             std::string& error) {
    try {
        nlohmann::json parsed = nlohmann::json::parse(body);
        if (!parsed.is_array() || parsed.empty() || !parsed[0].is_array()) {
            error = "unexpected response shape from free endpoint";
            return false;
        }

        std::string out;
        for (const auto& seg : parsed[0]) {
            if (seg.is_array() && !seg.empty() && seg[0].is_string()) {
                out += seg[0].get<std::string>();
            }
        }

        if (out.empty()) {
            error = "free endpoint returned no translation segments";
            return false;
        }

        translation = out;
        return true;
    } catch (const std::exception& e) {
        error = std::string("failed to parse free endpoint response: ") + e.what();
        return false;
    }
}
