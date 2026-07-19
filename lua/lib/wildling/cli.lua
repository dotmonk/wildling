local wildling = require("wildling")
local json = require("wildling.json")

local M = {}

local function parse_range(value)
    local dash = value:find("-", 1, true)
    if not dash then
        return nil
    end
    local start_str = value:sub(1, dash - 1)
    local end_str = value:sub(dash + 1)
    if not start_str:match("^%d+$") or not end_str:match("^%d+$") then
        return nil
    end
    local start = tonumber(start_str)
    local finish = tonumber(end_str)
    if start <= finish then
        return { start, finish }
    end
    return nil
end

local function load_dictionary_file(path)
    local handle, err = io.open(path, "r")
    if not handle then
        error(err)
    end
    local content = handle:read("*a")
    handle:close()
    local words = {}
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            words[#words + 1] = line
        end
    end
    return words
end

local function apply_dictionary(result, name, value)
    if type(value) == "table" then
        local words = {}
        for _, item in ipairs(value) do
            words[#words + 1] = tostring(item)
        end
        result.dictionaries[name] = words
        return
    end
    if type(value) == "string" then
        local f = io.open(value, "r")
        if f then
            f:close()
            local ok, words = pcall(load_dictionary_file, value)
            if ok then
                result.dictionaries[name] = words
            end
        end
    end
end

local function apply_template(result, path)
    local handle = io.open(path, "r")
    if not handle then
        io.stderr:write("Template file not found: " .. path .. "\n")
        os.exit(1)
    end
    local content = handle:read("*a")
    handle:close()

    local ok, template = pcall(json.parse_object, content)
    if not ok or type(template) ~= "table" then
        io.stderr:write("Invalid JSON template: " .. path .. "\n")
        os.exit(1)
    end

    if template.check == true then
        result.check = true
    end

    if type(template.select) == "table" then
        for _, val in ipairs(template.select) do
            local number = tonumber(val)
            if number and number >= 0 then
                result.selects[#result.selects + 1] = number
            end
        end
    end

    if type(template.range) == "table" then
        for _, range_str in ipairs(template.range) do
            local parsed = parse_range(tostring(range_str))
            if parsed then
                result.ranges[#result.ranges + 1] = parsed
            end
        end
    end

    if type(template.dictionaries) == "table" then
        for name, value in pairs(template.dictionaries) do
            if type(value) == "string" or type(value) == "table" then
                apply_dictionary(result, tostring(name), value)
            end
        end
    end

    if type(template.patterns) == "table" then
        for _, pattern in ipairs(template.patterns) do
            result.patterns[#result.patterns + 1] = tostring(pattern)
        end
    end
end

local function new_cli_args()
    return {
        selects = {},
        ranges = {},
        check = false,
        dictionaries = {},
        patterns = {},
        help = false,
        version = false,
    }
end

function M.parse_args(args)
    local result = new_cli_args()
    local i = 1
    while i <= #args do
        local arg = args[i]

        if arg == "--help" or arg == "-h" then
            result.help = true
            i = i + 1
        elseif arg == "--version" or arg == "-v" then
            result.version = true
            i = i + 1
        elseif arg == "--check" then
            result.check = true
            i = i + 1
        elseif arg == "--select" then
            i = i + 1
            if i > #args then
                break
            end
            local val = tonumber(args[i])
            if val and val >= 0 then
                result.selects[#result.selects + 1] = val
            end
            i = i + 1
        elseif arg == "--range" then
            i = i + 1
            if i > #args then
                break
            end
            local parsed = parse_range(args[i])
            if parsed then
                result.ranges[#result.ranges + 1] = parsed
            end
            i = i + 1
        elseif arg == "--dictionary" then
            i = i + 1
            if i > #args then
                break
            end
            local name, path = args[i]:match("^([^:]+):(.+)$")
            if name and path and name ~= "" and path ~= "" then
                apply_dictionary(result, name, path)
            end
            i = i + 1
        elseif arg == "--template" then
            i = i + 1
            if i > #args then
                io.stderr:write("Missing path for --template\n")
                os.exit(1)
            end
            apply_template(result, args[i])
            i = i + 1
        else
            result.patterns[#result.patterns + 1] = arg
            i = i + 1
        end
    end
    return result
end

function M.load_help_text()
    local here = debug.getinfo(1, "S").source:match("^@(.*/)")
    if not here then
        here = "./lib/wildling/"
    end
    local candidates = {
        here .. "help.txt",
        here .. "../../docs/help.txt",
    }
    for _, path in ipairs(candidates) do
        local handle = io.open(path, "r")
        if handle then
            local text = handle:read("*a")
            handle:close()
            return text
        end
    end
    return "wildling - pattern based string generator\n\nHelp text unavailable.\n"
end

local function format_list(values)
    if not values or #values == 0 then
        return ""
    end
    local parts = {}
    for _, value in ipairs(values) do
        parts[#parts + 1] = tostring(value)
    end
    return " " .. table.concat(parts, " ")
end

local function dictionary_keys(dict)
    local keys = {}
    for key in pairs(dict) do
        keys[#keys + 1] = key
    end
    return keys
end

function M.format_check_output(args, total, generators)
    local range_parts = {}
    for _, range in ipairs(args.ranges) do
        range_parts[#range_parts + 1] = range[1] .. "-" .. range[2]
    end

    local lines = {
        "patterns:" .. format_list(args.patterns),
        "dictionaries:" .. format_list(dictionary_keys(args.dictionaries)),
        "select:" .. format_list(args.selects),
        "range:" .. format_list(range_parts),
        "total: " .. tostring(total),
    }
    for _, gen in ipairs(generators) do
        lines[#lines + 1] = "generator: " .. gen.source .. " " .. tostring(gen:count())
    end
    return table.concat(lines, "\n")
end

function M.main(argv)
    argv = argv or arg
    if argv == nil then
        argv = {}
    end

    local args = M.parse_args(argv)

    if args.help then
        print(M.load_help_text():gsub("%s+$", ""))
        os.exit(0)
    end

    if args.version then
        print("wildling " .. wildling.VERSION)
        os.exit(0)
    end

    if #args.patterns == 0 then
        io.stderr:write("No pattern provided. Use --help for usage information.\n")
        os.exit(1)
    end

    local wildcard = wildling.create(args.patterns, args.dictionaries)

    if args.check then
        print(M.format_check_output(args, wildcard:count(), wildcard:generators()))
        os.exit(0)
    end

    if #args.selects > 0 or #args.ranges > 0 then
        local oor = false
        for _, index in ipairs(args.selects) do
            local value = wildcard:get(index)
            if value == false then
                io.stderr:write("out of range: " .. tostring(index) .. "\n")
                oor = true
            else
                print(value)
            end
        end
        for _, range in ipairs(args.ranges) do
            for index = range[1], range[2] do
                local value = wildcard:get(index)
                if value == false then
                    io.stderr:write("out of range: " .. tostring(index) .. "\n")
                    oor = true
                else
                    print(value)
                end
            end
        end
        if oor then
            os.exit(1)
        end
        os.exit(0)
    end

    local value = wildcard:next()
    while value ~= false do
        print(value)
        value = wildcard:next()
    end
end

return M
