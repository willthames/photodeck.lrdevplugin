local LrXml = import 'LrXml'
local logger = import 'LrLogger'( 'PhotoDeckPublishLightroomPlugin' )
logger:enable('logfile')

local xsltheader = [[
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="text"/>
]]

local xsltfooter = [[
  <xsl:template match="request|query-string|error"/>
</xsl:stylesheet>
]]

local PhotoDeckAPIXSLT = {}

PhotoDeckAPIXSLT.error = xsltheader .. [[
  <xsl:template match='/reply'>
return "<xsl:value-of select='error'/>"
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.ping = xsltheader .. [[
  <xsl:template match='/reply'>
return "<xsl:value-of select='message'/>"
  </xsl:template>
]] .. xsltfooter

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
local t = {}
    <xsl:for-each select='website'>
t["<xsl:value-of select='urlname'/>"] = {
     hostname = "<xsl:value-of select='hostname'/>",
     homeurl = "<xsl:value-of select='home-url'/>",
     title = "<xsl:value-of select='title'/>",
     rootgalleryuuid = "<xsl:value-of select='root-gallery-uuid'/>",
}
    </xsl:for-each>
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.galleries = xsltheader .. [[
  <xsl:template match='/reply/galleries'>
local t = {}
    <xsl:for-each select='gallery'>
t["<xsl:value-of select='uuid'/>"] = {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = "<xsl:value-of select='name'/>",
     uuid = "<xsl:value-of select='uuid'/>",
     description = "<xsl:value-of select='description'/>",
     urlpath = "<xsl:value-of select='url-path'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
     displaystyle = "<xsl:value-of select='gallery-display-style-uuid'/>",
}
   </xsl:for-each>
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.gallery = xsltheader .. [[
  <xsl:template match='/reply/gallery'>
local t = {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = "<xsl:value-of select='name'/>",
     uuid = "<xsl:value-of select='uuid'/>",
     description = "<xsl:value-of select='description'/>",
     urlpath = "<xsl:value-of select='url-path'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
     displaystyle = "<xsl:value-of select='gallery-display-style-uuid'/>",
}
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.createGallery = xsltheader .. [[
  <xsl:template match='/reply'>
local t = {
     uuid = "<xsl:value-of select='gallery-uuid'/>",
}
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.getPhoto = xsltheader .. [[
  <xsl:template match='/reply/media'>
local t = {
  uuid = "<xsl:value-of select='uuid'/>",
  filename = "<xsl:value-of select='file-name'/>",
  title = "<xsl:value-of select='title'/>",
  description = "<xsl:value-of select='description'/>",
  <xsl:apply-templates select='keywords'/>
  <xsl:apply-templates select='galleries'/>
}
return t
  </xsl:template>
  <xsl:template match='galleries'>
  galleries = {
    <xsl:for-each select='gallery'>
    "<xsl:value-of select='uuid'/>",
    </xsl:for-each>
  },
  </xsl:template>
  <xsl:template match='keywords'>
  keywords = {
    <xsl:for-each select='keyword'>
    "<xsl:value-of select='.'/>",
    </xsl:for-each>
  },
  </xsl:template>
]] .. xsltfooter


PhotoDeckAPIXSLT.photosInGallery = xsltheader .. [[
  <xsl:template match='/reply/gallery/*'/>
  <xsl:template match='/reply/gallery/medias'>
local t = {
    <xsl:for-each select='media'>
    "<xsl:value-of select='uuid'/>",
   </xsl:for-each>
}
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.subGalleriesInGallery = xsltheader .. [[
  <xsl:template match='/reply/galleries'>
local t = {}
    <xsl:for-each select='gallery'>
t["<xsl:value-of select='uuid'/>"] = {
     name = "<xsl:value-of select='name'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
     subgalleriescount = "<xsl:value-of select='subgalleries-count'/>",
     page = "<xsl:value-of select='page'/>",
     totalpages = "<xsl:value-of select='total-pages'/>"
}
    </xsl:for-each>
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.uploadPhoto = xsltheader .. [[
  <xsl:template match='/reply/message'/>
  <xsl:template match='/reply'>
local t = {
  uuid =  "<xsl:value-of select='media-uuid'/>",
  path =  "<xsl:value-of select='location'/>",
}
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.updatePhoto = xsltheader .. [[
  <xsl:template match='/reply'>
local t = {
  uuid =  "<xsl:value-of select='media-uuid'/>",
}
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.galleryDisplayStyles = xsltheader .. [[
  <xsl:template match='/reply/gallery-display-styles'>
local t = {}
    <xsl:for-each select='gallery-display-style'>
t["<xsl:value-of select='uuid'/>"] = {
     uuid = "<xsl:value-of select='uuid'/>",
     name = "<xsl:value-of select='name'/>",
}
   </xsl:for-each>
return t
  </xsl:template>
]] .. xsltfooter

PhotoDeckAPIXSLT.transform = function(xmlstring, xslt)
  if xmlstring and string.sub(xmlstring, 1, 5) == '<?xml' then
    local xml = LrXml.parseXml(xmlstring)
    local luastring = xml:transform(xslt)
    if luastring ~= '' then
      local f = assert(loadstring(luastring))
      return f()
    else
      logger:trace(xmlstring)
    end
  end
end

return PhotoDeckAPIXSLT
