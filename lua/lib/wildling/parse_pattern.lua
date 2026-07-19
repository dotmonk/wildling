local token_module = require("wildling.token")

local M = {}

local SPECIAL = {
    ["#"] = true,
    ["@"] = true,
    ["$"] = true,
    ["*"] = true,
    ["&"] = true,
    ["?"] = true,
    ["!"] = true,
    ["-"] = true,
    ["%"] = true,
}

local function is_special(c)
    return SPECIAL[c] == true
end

local function split_keeping_delimiters(input)
    if input == "" then
        return {}
    end

    local parts = {}
    local i = 1
    local literal_start = 1
    local len = #input

    while i <= len do
        local c = input:sub(i, i)

        if c == "\\" and i + 1 <= len and is_special(input:sub(i + 1, i + 1)) then
            if i > literal_start then
                parts[#parts + 1] = input:sub(literal_start, i - 1)
            end
            parts[#parts + 1] = input:sub(i, i + 1)
            i = i + 2
            literal_start = i
        elseif is_special(c) and i + 1 <= len and input:sub(i + 1, i + 1) == "{" then
            if i > literal_start then
                parts[#parts + 1] = input:sub(literal_start, i - 1)
            end
            local j = i + 2
            while j <= len and input:sub(j, j) ~= "}" do
                j = j + 1
            end
            if j <= len and input:sub(j, j) == "}" then
                parts[#parts + 1] = input:sub(i, j)
                i = j + 1
                literal_start = i
            else
                if i > literal_start then
                    parts[#parts + 1] = input:sub(literal_start, i - 1)
                end
                parts[#parts + 1] = c
                i = i + 1
                literal_start = i
            end
        elseif is_special(c) then
            if i > literal_start then
                parts[#parts + 1] = input:sub(literal_start, i - 1)
            end
            parts[#parts + 1] = c
            i = i + 1
            literal_start = i
        else
            i = i + 1
        end
    end

    if literal_start <= len then
        parts[#parts + 1] = input:sub(literal_start)
    end

    return parts
end

local function parse_length_with_variants(part, variants)
    local start_length = 1
    local end_length = 1

    local open = part:find("{", 1, true)
    if open then
        local close = part:find("}", open, true)
        if close then
            local inner = part:sub(open + 1, close - 1)
            local dash = inner:find("-", 1, true)
            if dash then
                local s = tonumber(inner:sub(1, dash - 1))
                local e = tonumber(inner:sub(dash + 1))
                if s and e then
                    start_length = s
                    end_length = e
                end
            else
                local n = tonumber(inner)
                if n then
                    start_length = n
                    end_length = n
                end
            end
        end
    end

    return {
        variants = variants,
        startLength = start_length,
        endLength = end_length,
        src = part,
    }
end

local function parse_length_with_string(part)
    local open = part:find("{'", 1, true)
    if not open then
        return false
    end

    local after_open = open + 2
    local rest = part:sub(after_open)
    local close_quote = nil
    for idx = #rest, 1, -1 do
        if rest:sub(idx, idx) == "'" then
            close_quote = idx
            break
        end
    end
    if not close_quote then
        return false
    end

    local content = rest:sub(1, close_quote - 1)
    local after_quote = rest:sub(close_quote + 1)

    if not after_quote:match("^}") and not after_quote:match("^,") then
        if not after_quote:find("}", 1, true) then
            return false
        end
    end

    local start_length = 1
    local end_length = 1

    if after_quote:sub(1, 1) == "," then
        local stripped = after_quote:sub(2)
        if stripped:sub(-1) == "}" then
            stripped = stripped:sub(1, -2)
        end
        local dash = stripped:find("-", 1, true)
        if dash then
            local s = tonumber(stripped:sub(1, dash - 1))
            local e = tonumber(stripped:sub(dash + 1))
            if s and e then
                start_length = s
                end_length = e
            end
        else
            local n = tonumber(stripped)
            if n then
                start_length = n
                end_length = n
            end
        end
    elseif after_quote:sub(1, 1) ~= "}" then
        return false
    end

    return {
        string = content,
        startLength = start_length,
        endLength = end_length,
        src = part,
    }
end

local function chars_as_variants(s)
    local variants = {}
    for i = 1, #s do
        variants[#variants + 1] = s:sub(i, i)
    end
    return variants
end

local function simple_tokenizer(variants_string)
    local variants = chars_as_variants(variants_string)
    return function(part)
        return token_module.create_token(parse_length_with_variants(part, variants))
    end
end

local function dictionary_tokenizer(part, dictionaries)
    local options = parse_length_with_string(part)
    if options == false then
        options = {
            variants = { part },
            startLength = 1,
            endLength = 1,
            src = part,
        }
    elseif options.string and options.string ~= "" and dictionaries[options.string] == nil then
        options = {
            variants = { part },
            startLength = 1,
            endLength = 1,
            src = part,
        }
    else
        options.variants = dictionaries[options.string or ""] or {}
    end
    return token_module.create_token(options)
end

local function words_tokenizer(part)
    local options = parse_length_with_string(part)

    if options == false then
        options = {
            variants = { part },
            startLength = 1,
            endLength = 1,
            src = part,
        }
    else
        local variants = {}
        local work_string = options.string or ""
        local index = 1
        while index <= #work_string do
            if work_string:sub(index, index + 1) == "\\," then
                index = index + 2
            elseif work_string:sub(index, index) == "," then
                variants[#variants + 1] = work_string:sub(1, index - 1)
                work_string = work_string:sub(index + 1)
                index = 1
            else
                index = index + 1
            end
        end
        variants[#variants + 1] = work_string
        for i, variant in ipairs(variants) do
            variants[i] = variant:gsub("\\,", ",")
        end
        options.variants = variants
    end

    return token_module.create_token(options)
end

local function part_to_token(part, dictionaries)
    local tokenizers = {
        ["#"] = simple_tokenizer("0123456789"),
        ["@"] = simple_tokenizer("abcdefghijklmnopqrstuvwxyz"),
        ["*"] = simple_tokenizer("abcdefghijklmnopqrstuvwxyz0123456789"),
        ["-"] = simple_tokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
        ["!"] = simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        ["?"] = simple_tokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),
        ["&"] = simple_tokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        ["%"] = function(p)
            return dictionary_tokenizer(p, dictionaries)
        end,
        ["$"] = words_tokenizer,
    }

    local tokenizer = (#part > 0) and tokenizers[part:sub(1, 1)] or nil
    local is_escaped = #part > 1 and part:sub(1, 1) == "\\" and tokenizers[part:sub(2, 2)] ~= nil

    if tokenizer then
        return tokenizer(part)
    end
    if is_escaped then
        return token_module.create_token({
            variants = { part:sub(2) },
            src = part,
        })
    end
    return token_module.create_token({
        variants = { part },
        src = part,
    })
end

function M.parse_pattern(input_pattern, dictionaries)
    dictionaries = dictionaries or {}
    local parts = split_keeping_delimiters(input_pattern)
    local tokens = {}
    for _, part in ipairs(parts) do
        if part ~= "" then
            tokens[#tokens + 1] = part_to_token(part, dictionaries)
        end
    end
    return tokens
end

return M
