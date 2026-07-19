local M = {}

local function default_integer(option, fallback)
    if type(option) == "number" and option >= 0 and option == math.floor(option) then
        return option
    end
    return fallback
end

local function int_pow(base, exp)
    local result = 1
    for _ = 1, exp do
        result = result * base
    end
    return result
end

local Token = {}
Token.__index = Token

function Token.new(options)
    options = options or {}
    local self = setmetatable({}, Token)
    self._src = options.src or ""
    self._start_length = default_integer(options.startLength, 1)
    self._end_length = default_integer(options.endLength, 1)
    self._variants = options.variants or {}
    self._count = 0
    for length = self._start_length, self._end_length do
        self._count = self._count + int_pow(#self._variants, length)
    end
    return self
end

function Token:count()
    return self._count
end

function Token:src()
    return self._src
end

function Token:get(index)
    if index > self._count - 1 or index < 0 then
        return ""
    end

    if index == 0 and self._start_length == 0 then
        return ""
    end

    local index_with_offset = index
    local string_length = self._start_length
    for length = self._start_length, self._end_length do
        string_length = length
        local offset_count = int_pow(#self._variants, length)
        if index_with_offset < offset_count then
            break
        end
        index_with_offset = index_with_offset - offset_count
    end

    local string_array = {}
    for _ = 1, string_length do
        if #self._variants == 0 then
            break
        end
        local variant_index = index_with_offset % #self._variants
        index_with_offset = index_with_offset // #self._variants
        string_array[#string_array + 1] = self._variants[variant_index + 1]
    end
    return table.concat(string_array)
end

function M.create_token(options)
    return Token.new(options)
end

return M
