local TableUtils = {}

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

-- for LightRoom tables which are typically of the form
-- { { field = "Content-Type", value = "text/html" },
--   { field = "Server", value = "Apache" },
-- }

function TableUtils.toString(t, sep)
  sep = sep or '\n'
  local result = {}
  for _, v in ipairs(t) do
    table.insert(result, v.field .. ' = ' .. v.value)
  end
  return table.concat(result, sep)
end

return TableUtils
