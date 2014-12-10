local PhotoDeckXml = {}

-- local logger = import 'LrLogger'( 'PhotoDeckXml' )
-- logger:enable('print')

--[[ PhotoDeckXml.toTable
--
-- <hello>world</hello> => { hello = 'world' }
-- <hello><child1>goodbye</child1><child2>cruel</child2></hello> =>
--   { hello = { { child1 = 'goodbye' }, { child2 = 'cruel' } } }
--]]
function PhotoDeckXml.toTable(xml)
  local result = {}
  result[xml:name()] = {}
  if xml:childCount() then
    for i = 1, xml:childCount() do
      if xml:childAtIndex(i):type() == 'text' then
        result[xml:name()] = xml:text()
      else
        table.insert(result[xml:name()], PhotoDeckXml.toTable(xml:childAtIndex(i)))
      end
    end
  else
    assert(nil, 'Should not get here')
    -- result[xml:name()] = xml:text()
  end
  return result
end

function PhotoDeckXml.childWithName(xml, name)
  for i = 1, xml:childCount() do
    if xml:childAtIndex(i):name() == name then
      return xml:childAtIndex(i)
    end
  end
end

return PhotoDeckXml
