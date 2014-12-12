local LrXml = import 'LrXml'
local logger = import 'LrLogger'('PhotoDeckAPIXSLT')
logger:enable('print')

local xsltheader = [[
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="text"/>
]]

local xsltfooter = [[
  <xsl:template match="request|query-string"/>
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
local t = {}
    <xsl:for-each select='gallery'>
t["<xsl:value-of select='url-path'/>"] = {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = "<xsl:value-of select='name'/>",
     uuid = "<xsl:value-of select='uuid'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
}
t["<xsl:value-of select='uuid'/>"] = {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = "<xsl:value-of select='name'/>",
     urlpath = "<xsl:value-of select='url-path'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
}
   </xsl:for-each>
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.transform = function(xmlstring, xslt)
  local xml = LrXml.parseXml(xmlstring)
  local luastring = xml:transform(xslt)
  local f = assert(loadstring(luastring))
  return f()
end

return PhotoDeckAPIXSLT
