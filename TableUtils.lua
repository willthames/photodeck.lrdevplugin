local TableUtils = {}

local TypeUtils = require 'TypeUtils'
local isString = TypeUtils.isString
local isTable = TypeUtils.isTable

function TableUtils.map(t, f)
  local result = {}
  for k, v in pairs(t) do
    result[k] = f(v)
  end
  return result
end

function TableUtils.filter(t, p)
  local result = {}
  for k, v in pairs(t) do
    if p(v) then
      result[k] = v
    end
  end
  return result
end

function TableUtils.toString(t, sep, level, indent)
  level = level or 0
  sep = sep or ', '
  indent = indent or 2
  local result = {}
  for k, v in pairs(t) do
    local current = string.rep(' ', level*indent)
    if isString(k) then
      current = current .. k .. ' = '
    end
    if isTable(v) then
      current = current .. TableUtils.toString(v, sep, level+1, indent)
    else
      current = current .. v
    end
    table.insert(result, current)
  end
  return table.concat(result, sep)
end

return TableUtils
