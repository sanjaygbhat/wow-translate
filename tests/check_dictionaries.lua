-- Validates every offline dictionary with the engine's own normalization.
-- Run from the repository root:  lua5.1 tests/check_dictionaries.lua
-- Fails on format errors; prints collisions (a form listed twice) as warnings.

local DIR = "Interface/AddOns/WoWTranslate/"
local WT = { Debug = function() end }
local function load(f) assert(loadfile(DIR .. f))("WoWTranslate", WT) end
load("Engine/Text.lua")

local collected = {}
WT.AddDictionary = function(lang, lines)
    collected[lang] = collected[lang] or {}
    for _, l in ipairs(lines) do table.insert(collected[lang], l) end
end

local errors, warnings = {}, 0
local LANGS = { "zh", "ko", "ja", "ru", "de", "fr", "es", "pt" }
for _, lang in ipairs(LANGS) do
    for part = 1, 3 do
        local path = DIR .. "Dictionaries/" .. lang .. "_" .. part .. ".lua"
        local chunk, err = loadfile(path)
        if not chunk then
            errors[#errors + 1] = err
        else
            local ok, e = pcall(chunk, "WoWTranslate", WT)
            if not ok then errors[#errors + 1] = path .. ": " .. tostring(e) end
        end
    end
end

local total = 0
for _, lang in ipairs(LANGS) do
    local lines = collected[lang] or {}
    local seen, dup = {}, 0
    for i, line in ipairs(lines) do
        if type(line) ~= "string" then
            errors[#errors + 1] = lang .. " entry " .. i .. " is not a string"
        else
            local fields, pos = {}, 1
            while true do
                local bar = line:find("|", pos, true)
                if not bar then fields[#fields + 1] = line:sub(pos) break end
                fields[#fields + 1] = line:sub(pos, bar - 1)
                pos = bar + 1
            end
            if #fields < 2 then errors[#errors + 1] = lang .. ": no foreign form in \"" .. line .. "\"" end
            for f = 2, #fields do
                local form = fields[f]
                if form == "" then
                    errors[#errors + 1] = lang .. ": empty form in \"" .. line .. "\""
                else
                    local key = WT.Text.normalize(lang, form)
                    if seen[key] and seen[key] ~= fields[1] then
                        dup = dup + 1
                    end
                    seen[key] = seen[key] or fields[1]
                end
            end
        end
    end
    total = total + #lines
    warnings = warnings + dup
    print(string.format("%s: %5d entries, %3d forms that also appear under another meaning (first one wins)", lang, #lines, dup))
end
print(string.format("total: %d entries", total))
for _, e in ipairs(errors) do print("ERROR: " .. e) end
os.exit(#errors == 0 and 0 or 1)
