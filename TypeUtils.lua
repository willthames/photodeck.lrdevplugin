local TypeUtils = {}

function TypeUtils.isType(v, t)
  return type(v) == t
end

function TypeUtils.isString(v)
  return TypeUtils.isType(v, 'string')
end

function TypeUtils.isNumber(v)
  return TypeUtils.isType(v, 'number')
end

function TypeUtils.isTable(v)
  return TypeUtils.isType(v, 'table')
end

return TypeUtils
