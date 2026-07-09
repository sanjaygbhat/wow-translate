// Host-side unit test for the Google Free (gtx) response parser.
// Feeds REAL captured endpoint responses (see comments) plus hostile inputs.
// Build & run:  c++ -std=c++17 -I dll/third_party -I dll/src tests/gtx_parser_test.cpp -o /tmp/gtx_test && /tmp/gtx_test
#include "../dll/src/gtx_parser.h"
#include <cstdio>
#include <string>

static int failures = 0;
static void expect(bool cond, const char* what) {
    if (!cond) { std::printf("FAIL: %s\n", what); failures++; }
    else       { std::printf("ok:   %s\n", what); }
}

int main() {
    std::string out, err;

    // Captured live 2026-07-10: basic zh->en
    expect(ParseGtxResponse(
        R"([[["Hello World","你好世界",null,null,10]],null,"zh-CN",null,null,null,null,[]])",
        out, err) && out == "Hello World", "basic single-segment");

    // Captured live: multi-sentence => segments concatenated
    expect(ParseGtxResponse(
        R"([[["I am a mage. ","我是法师。",null,null,3,null,null,[[]],[[["af64405095a399ceb1e05c7abb7cda66","zh_en_2023q1.md"]]]],["Where are you?","你在哪里？",null,null,10]],null,"zh-CN",null,null,null,null,[]])",
        out, err) && out == "I am a mage. Where are you?", "multi-segment concatenation");

    // Captured live: invalid UTF-8 input comes back as U+FFFD, still parses
    expect(ParseGtxResponse(
        "[[[\"\xEF\xBF\xBD\",\"\xEF\xBF\xBD\",null,null,3]],null,\"zh-CN\",null,null,null,null,[]]",
        out, err) && out == "\xEF\xBF\xBD", "replacement-char response");

    // Hostile: HTML error page (what a block/captcha would return)
    expect(!ParseGtxResponse("<html><body>captcha</body></html>", out, err),
           "HTML error page rejected without throwing");

    // Hostile: empty body / truncated JSON / wrong shapes
    expect(!ParseGtxResponse("", out, err), "empty body rejected");
    expect(!ParseGtxResponse("[[[\"Hello", out, err), "truncated JSON rejected");
    expect(!ParseGtxResponse("{\"data\":{}}", out, err), "object (paid-API shape) rejected");
    expect(!ParseGtxResponse("[null,null]", out, err), "null first element rejected");
    expect(!ParseGtxResponse("[[]]", out, err), "no segments rejected");
    expect(!ParseGtxResponse("[[[123]]]", out, err), "non-string segment rejected");

    // Segment with quotes/escapes survives round-trip
    expect(ParseGtxResponse(
        R"([[["He said \"hi\" \\ done","x",null,null,1]],null,"zh-CN"])",
        out, err) && out == "He said \"hi\" \\ done", "escapes preserved");

    if (failures) { std::printf("%d FAILURES\n", failures); return 1; }
    std::printf("ALL GREEN (parser)\n");
    return 0;
}
