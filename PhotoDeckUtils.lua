local PhotoDeckUtils = {}

function PhotoDeckUtils.isType(v, t)
  return type(v) == t
end

function PhotoDeckUtils.isString(v)
  return PhotoDeckUtils.isType(v, 'string')
end

function PhotoDeckUtils.isNumber(v)
  return PhotoDeckUtils.isType(v, 'number')
end

function PhotoDeckUtils.isTable(v)
  return PhotoDeckUtils.isType(v, 'table')
end

function PhotoDeckUtils.isFunction(v)
  return PhotoDeckUtils.isType(v, 'function')
end

function PhotoDeckUtils.isBoolean(v)
  return PhotoDeckUtils.isType(v, 'boolean')
end

function PhotoDeckUtils.toString(v)
  if PhotoDeckUtils.isBoolean(v) then
    return v and 'true' or 'false'
  end
  if PhotoDeckUtils.isFunction(v) then
    return 'function'
  end
  return v
end

function PhotoDeckUtils.printTable(t)
  if PhotoDeckUtils.isTable(t) then
    local result = {}
    for k, v in pairs(t) do
      local current = ''
      if PhotoDeckUtils.isString(k) then
        current = current .. k .. ' = '
      end
      table.insert(result, current .. PhotoDeckUtils.printTable(v))
    end
    return '{ ' .. table.concat(result, ', ') .. ' }'
  else
    return PhotoDeckUtils.toString(t)
  end
end

function PhotoDeckUtils.map(t, f)
  local result = {}
  for k, v in pairs(t) do
    result[k] = f(v)
  end
  return result
end

function PhotoDeckUtils.filter(t, p)
  local result = {}
  for k, v in pairs(t) do
    if p(v) then
      if PhotoDeckUtils.isNumber(k) then
        table.insert(result, v)
      else
        result[k] = v
      end
    end
  end
  return result
end

-- for LightRoom tables which are typically of the form
-- { { field = "Content-Type", value = "text/html" },
--   { field = "Server", value = "Apache" },
-- }

function PhotoDeckUtils.printLrTable(t, sep)
  sep = sep or '\n'
  local result = {}
  for _, v in ipairs(t) do
    table.insert(result, v.field .. ' = ' .. v.value)
  end
  return table.concat(result, sep)
end

return PhotoDeckUtils
