local TableUtils = require 'TableUtils'
local filter = TableUtils.filter
local map = TableUtils.map

local t = { 'this', 'is', 'a', 'list' }

local tf = filter(t, function (v) return string.find(v, 'is') end)
print(TableUtils.toString(tf))

local d = { deeply = { this = 'has', more = 'complicated' }, structure = 5 }

print(TableUtils.toString(d, '\n'))

local d2 = { key = 'value', hello = 'world', this = 'life' }

print(TableUtils.toString(map(d2, function(v) return v .. '!' end)))
