#!/usr/bin/env lua5.4

local root = arg[0]:match("(.*/)")
if not root then
    root = "./"
end
root = root:gsub("/bin/$", "/")

package.path = root .. "lib/?.lua;" .. root .. "lib/?/init.lua;" .. package.path

local argv = {}
for i = 1, #arg do
    argv[#argv + 1] = arg[i]
end

require("wildling.cli").main(argv)
