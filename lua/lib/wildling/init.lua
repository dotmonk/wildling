local generator = require("wildling.generator")

local M = {}

M.VERSION = "2.0.2"

local Wildling = {}
Wildling.__index = Wildling

function Wildling.new(patterns, dictionaries)
    local self = setmetatable({}, Wildling)
    self._dictionaries = dictionaries or {}
    self._generators = {}
    self._pattern_count = 0
    for _, pattern in ipairs(patterns) do
        local gen = generator.create_generator(pattern, self._dictionaries)
        self._generators[#self._generators + 1] = gen
        self._pattern_count = self._pattern_count + gen:count()
    end
    self._internal_index = 0
    return self
end

function Wildling:index()
    return self._internal_index
end

function Wildling:count()
    return self._pattern_count
end

function Wildling:reset()
    self._internal_index = 0
end

function Wildling:next()
    if self._internal_index == self._pattern_count then
        return false
    end
    self._internal_index = self._internal_index + 1
    return self:get(self._internal_index - 1)
end

function Wildling:generators()
    return self._generators
end

function Wildling:get(index)
    if index > self._pattern_count - 1 or index < 0 then
        return false
    end

    local segment_index = 0
    for _, gen in ipairs(self._generators) do
        local pattern_index = index - segment_index
        if pattern_index < gen:count() then
            return gen:get(pattern_index)
        end
        segment_index = segment_index + gen:count()
    end
    return false
end

function M.create(patterns, dictionaries)
    return Wildling.new(patterns, dictionaries)
end

M.createWildling = M.create

return M
