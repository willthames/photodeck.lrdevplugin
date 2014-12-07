local TableUtils = require 'TableUtils'
local filter = TableUtils.filter
local map = TableUtils.map

local d2 = {
  { field = 'key', value = 'value' }, 
  { field = 'hello', value = 'world'}, 
  { field = 'this', value = 'life' }
}

print(TableUtils.toString(d2))

print(TableUtils.toString(map(d2, function(v) v.value = v.value .. '!'; return v end)))

print(TableUtils.toString(filter(d2, function(v) return string.find(v.value, 'e') end)))

local lrt = {
  { field = 'Server', value = 'nginx' },
  { field = 'Content-Type', value = 'aplication/xml' },
}

local lrtf = filter(lrt, function(v)
    return v
  end)

print(TableUtils.toString(lrtf))
