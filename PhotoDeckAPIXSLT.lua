local logger = import 'LrLogger'('PhotoDeckAPIXSLT')
logger:enable('print')

local xsltheader = [[
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
   <xsl:output method="text"/>
]]

local xsltfooter = [[
</xsl:stylesheet>
]]

local PhotoDeckAPIXSLT = {}

PhotoDeckAPIXSLT.whoami = xsltheader .. [[
  <xsl:template match='/reply/user'>
{
  firstname = "<xsl:value-of select='firstname'/>",
  lastname = "<xsl:value-of select='lastname'/>",
  email = "<xsl:value-of select='email'/>",
},
  </xsl:template>
  <xsl:template match='/reply/request'/>
]] .. xsltfooter

PhotoDeckAPIXSLT.websites = xsltheader .. [[
  <xsl:template match='/reply/websites'>
    <xsl:for-each select='website'>
{ <xsl:value-of select='urlname'/> =
  {
     hostname = "<xsl:value-of select='hostname'/>",
     hosturl = "<xsl:value-of select='host-url'/>",
     title = "<xsl:value-of select='title'/>",
  },
},
    </xsl:for-each>
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.galleries = xsltheader .. [[
  <xsl:template match='/reply/galleries'>
    <xsl:for-each select='gallery'>
{ <xsl:value-of select='url-path'/> =
  {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = "<xsl:value-of select='name'/>",
     uuid = "<xsl:value-of select='uuid'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
  },
},
{ <xsl:value-of select='uuid'/> =
  {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = "<xsl:value-of select='name'/>",
     urlpath = "<xsl:value-of select='url-path'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
  },
},
    </xsl:for-each>
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.transform = function(xml, xslt)
  local luastring = xml:transform(xslt)
  logger:trace(luastring)
  local f = assert(loadstring('return ' .. luastring))
  return f()
end

return PhotoDeckAPIXSLT
