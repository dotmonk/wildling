local parse_pattern = require("wildling.parse_pattern")

local M = {}

local Generator = {}
Generator.__index = Generator

function Generator.new(input_pattern, dictionaries)
    local self = setmetatable({}, Generator)
    self.source = input_pattern
    self._tokens = parse_pattern.parse_pattern(input_pattern, dictionaries)
    self._count = 1
    for _, token in ipairs(self._tokens) do
        self._count = self._count * token:count()
    end
    return self
end

function Generator:count()
    return self._count
end

function Generator:tokens()
    return self._tokens
end

function Generator:get(index)
    if index > self._count - 1 or index < 0 then
        return ""
    end

    local string_array = {}
    local index_with_offset = index
    for _, token in ipairs(self._tokens) do
        string_array[#string_array + 1] = token:get(index_with_offset % token:count())
        index_with_offset = index_with_offset // token:count()
    end
    return table.concat(string_array)
end

function M.create_generator(input_pattern, dictionaries)
    return Generator.new(input_pattern, dictionaries)
end

return M
