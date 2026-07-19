local M = {}

local JsonParser = {}
JsonParser.__index = JsonParser

function JsonParser.new(text)
    return setmetatable({ text = text, pos = 1 }, JsonParser)
end

function JsonParser:skip_whitespace()
    while self.pos <= #self.text do
        local c = self.text:sub(self.pos, self.pos)
        if c == " " or c == "\n" or c == "\r" or c == "\t" then
            self.pos = self.pos + 1
        else
            return
        end
    end
end

function JsonParser:peek(expected)
    return self.pos <= #self.text and self.text:sub(self.pos, self.pos) == expected
end

function JsonParser:expect(expected)
    self:skip_whitespace()
    if not self:peek(expected) then
        error("Expected '" .. expected .. "' at " .. tostring(self.pos))
    end
    self.pos = self.pos + 1
end

function JsonParser:parse_string()
    self:expect('"')
    local out = {}
    while self.pos <= #self.text do
        local c = self.text:sub(self.pos, self.pos)
        self.pos = self.pos + 1
        if c == '"' then
            return table.concat(out)
        end
        if c == "\\" then
            if self.pos > #self.text then
                error("Unterminated escape")
            end
            local esc = self.text:sub(self.pos, self.pos)
            self.pos = self.pos + 1
            if esc == '"' or esc == "\\" or esc == "/" then
                out[#out + 1] = esc
            elseif esc == "b" then
                out[#out + 1] = string.char(8)
            elseif esc == "f" then
                out[#out + 1] = string.char(12)
            elseif esc == "n" then
                out[#out + 1] = "\n"
            elseif esc == "r" then
                out[#out + 1] = "\r"
            elseif esc == "t" then
                out[#out + 1] = "\t"
            elseif esc == "u" then
                if self.pos + 3 > #self.text then
                    error("Invalid unicode escape")
                end
                local code = tonumber(self.text:sub(self.pos, self.pos + 3), 16)
                if not code then
                    error("Invalid unicode escape")
                end
                out[#out + 1] = utf8.char(code)
                self.pos = self.pos + 4
            else
                error("Invalid escape \\" .. esc)
            end
        else
            out[#out + 1] = c
        end
    end
    error("Unterminated string")
end

function JsonParser:parse_number()
    local start = self.pos
    if self:peek("-") then
        self.pos = self.pos + 1
    end
    while self.pos <= #self.text and self.text:sub(self.pos, self.pos):match("%d") do
        self.pos = self.pos + 1
    end
    local is_double = false
    if self:peek(".") then
        is_double = true
        self.pos = self.pos + 1
        while self.pos <= #self.text and self.text:sub(self.pos, self.pos):match("%d") do
            self.pos = self.pos + 1
        end
    end
    if self.pos <= #self.text then
        local c = self.text:sub(self.pos, self.pos)
        if c == "e" or c == "E" then
            is_double = true
            self.pos = self.pos + 1
            if self:peek("+") or self:peek("-") then
                self.pos = self.pos + 1
            end
            while self.pos <= #self.text and self.text:sub(self.pos, self.pos):match("%d") do
                self.pos = self.pos + 1
            end
        end
    end
    local raw = self.text:sub(start, self.pos - 1)
    if is_double then
        return tonumber(raw)
    end
    return tonumber(raw)
end

function JsonParser:parse_boolean()
    if self.text:sub(self.pos, self.pos + 3) == "true" then
        self.pos = self.pos + 4
        return true
    end
    if self.text:sub(self.pos, self.pos + 4) == "false" then
        self.pos = self.pos + 5
        return false
    end
    error("Invalid boolean at " .. tostring(self.pos))
end

function JsonParser:parse_null()
    if self.text:sub(self.pos, self.pos + 3) == "null" then
        self.pos = self.pos + 4
        return nil
    end
    error("Invalid null at " .. tostring(self.pos))
end

function JsonParser:parse_array()
    self:expect("[")
    local array = {}
    self:skip_whitespace()
    if self:peek("]") then
        self.pos = self.pos + 1
        return array
    end
    while true do
        array[#array + 1] = self:parse_value()
        self:skip_whitespace()
        if self:peek("]") then
            self.pos = self.pos + 1
            return array
        end
        self:expect(",")
    end
end

function JsonParser:parse_object()
    self:expect("{")
    local obj = {}
    self:skip_whitespace()
    if self:peek("}") then
        self.pos = self.pos + 1
        return obj
    end
    while true do
        self:skip_whitespace()
        local key = self:parse_string()
        self:skip_whitespace()
        self:expect(":")
        obj[key] = self:parse_value()
        self:skip_whitespace()
        if self:peek("}") then
            self.pos = self.pos + 1
            return obj
        end
        self:expect(",")
    end
end

function JsonParser:parse_value()
    self:skip_whitespace()
    if self.pos > #self.text then
        error("Unexpected end of JSON")
    end
    local c = self.text:sub(self.pos, self.pos)
    if c == "{" then
        return self:parse_object()
    elseif c == "[" then
        return self:parse_array()
    elseif c == '"' then
        return self:parse_string()
    elseif c == "t" or c == "f" then
        return self:parse_boolean()
    elseif c == "n" then
        return self:parse_null()
    elseif c == "-" or c:match("%d") then
        return self:parse_number()
    end
    error("Unexpected character at " .. tostring(self.pos))
end

function M.parse(text)
    local parser = JsonParser.new(text)
    local value = parser:parse_value()
    parser:skip_whitespace()
    if parser.pos ~= #parser.text + 1 then
        error("Unexpected trailing JSON content")
    end
    return value
end

function M.parse_object(text)
    local value = M.parse(text)
    if type(value) ~= "table" then
        error("Template root must be a JSON object")
    end
    return value
end

return M
