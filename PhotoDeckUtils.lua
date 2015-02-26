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
  return tostring(v)
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

function PhotoDeckUtils.basename(path)
  return string.match(path, '([^/\\]*)$')
end

-- parses datetimes formatted as 2015-02-05T21:30:38+01:00
function PhotoDeckUtils.XMLDateTimeToCoca(s)
  local coca = nil
  if s then
    local year, month, day = string.match(s, '([12][0-9][0-9][0-9])-([0-1][0-9])-([0-3][0-9])')
    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    if year >= 1000 and month >= 1 and day >= 1 then
      local hour, min, sec = string.match(s, 'T([0-2][0-9]):([0-6][0-9]):([0-6][0-9])')
      hour = tonumber(hour) or 0
      min = tonumber(min) or 0
      sec = tonumber(sec) or 0
      local tz = string.match(s, 'T[0-2][0-9]:[0-6][0-9]:[0-6][0-9](.*)') or 'Z'
      if tz == 'Z' then
        tz = 0
      else
        local tz_dir, tz_h, tz_m = string.match(tz, '([+-])([0-2][0-9]):([0-6][0-6])')
        if tz_dir == nil then
          tz_dir, tz_h = string.match(tz, '([+-])([0-2][0-9])')
        end
        tz_h = tonumber(tz_h) or 0
        tz_m = tonumber(tz_m) or 0
        tz = ((tz_h * 60) + tz_m) * 60
        if tz_dir == '-' then
          tz = -tz
        end
      end
      coca = LrDate.timeFromComponents(year, month, day, hour, min, sec, tz)
    end
  end
  return coca
end

return PhotoDeckUtils
