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
local t = {
  firstname = "<xsl:value-of select='firstname'/>",
  lastname = "<xsl:value-of select='lastname'/>",
  email = "<xsl:value-of select='email'/>",
}
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.websites = xsltheader .. [[
  <xsl:template match='/reply/websites'>
    <xsl:for-each select='website'>
local t = { <xsl:value-of select='urlname'/> =
  {
     hostname = "<xsl:value-of select='hostname'/>",
     homeurl = "<xsl:value-of select='home-url'/>",
     title = "<xsl:value-of select='title'/>",
  },
}
return t
    </xsl:for-each>
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.galleries = xsltheader .. [[
  <xsl:template match='/reply/galleries'>
local t = {}
    <xsl:for-each select='gallery'>
t["<xsl:value-of select='name'/>"] = {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = "<xsl:value-of select='name'/>",
     uuid = "<xsl:value-of select='uuid'/>",
     urlpath = "<xsl:value-of select='url-path'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
}
t["<xsl:value-of select='uuid'/>"] = {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = "<xsl:value-of select='name'/>",
     uuid = "<xsl:value-of select='uuid'/>",
     urlpath = "<xsl:value-of select='url-path'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
}
   </xsl:for-each>
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.photosInGallery = xsltheader .. [[
  <xsl:template match='/reply/gallery/medias'>
local t = {
    <xsl:for-each select='media'>
    "<xsl:value-of select='uuid'/>",
   </xsl:for-each>
}
return t
  </xsl:template>
  <xsl:template match='/reply/gallery/*'/>
]] .. xsltfooter

PhotoDeckAPIXSLT.transform = function(xmlstring, xslt)
  local xml = LrXml.parseXml(xmlstring)
  local luastring = xml:transform(xslt)
  logger:trace(luastring)
  local f = assert(loadstring(luastring))
  return f()
end

return PhotoDeckAPIXSLT
