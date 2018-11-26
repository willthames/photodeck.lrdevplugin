local LrXml = import 'LrXml'
local logger = import 'LrLogger'( 'PhotoDeckPublishLightroomPlugin' )
logger:enable('logfile')

local xsltheader = [====[
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
  <xsl:template match="/reply/*"/>
]====]

local xsltfooter = [====[
</xsl:stylesheet>
]====]

local PhotoDeckAPIXSLT = {}

PhotoDeckAPIXSLT.error = xsltheader .. [=====[
  <xsl:template match='/reply'>
return "<xsl:value-of select='error'/>"
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.ping = xsltheader .. [=====[
  <xsl:template match='/reply'>
return [====[<xsl:value-of select='message'/>]====]
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.user = xsltheader .. [=====[
  <xsl:template match='/reply/user'>
local t = {
  firstname = [====[<xsl:value-of select='firstname'/>]====],
  lastname = [====[<xsl:value-of select='lastname'/>]====],
  email = "<xsl:value-of select='email'/>",
}
return t
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.websites = xsltheader .. [=====[
  <xsl:template match='/reply/websites'>
local t = {}
    <xsl:for-each select='website'>
t["<xsl:value-of select='urlname'/>"] = {
     hostname = "<xsl:value-of select='hostname'/>",
     homeurl = "<xsl:value-of select='home-url'/>",
     title = [====[<xsl:value-of select='title'/>]====],
     uuid = "<xsl:value-of select='uuid'/>",
     rootgalleryuuid = "<xsl:value-of select='root-gallery-uuid'/>",
}
    </xsl:for-each>
return t
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.galleries = xsltheader .. [=====[
  <xsl:template match='/reply/galleries'>
LrDate = import 'LrDate'
local PhotoDeckUtils = require 'PhotoDeckUtils'

local t = {}
    <xsl:for-each select='gallery'>
t["<xsl:value-of select='uuid'/>"] = {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = [====[<xsl:value-of select='name'/>]====],
     uuid = "<xsl:value-of select='uuid'/>",
     description = [====[<xsl:value-of select='description'/>]====],
     urlpath = "<xsl:value-of select='url-path'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
     publishedat = PhotoDeckUtils.XMLDateTimeToCoca("<xsl:value-of select='published-at'/>"),
     mediascount = "<xsl:value-of select='medias-count'/>",
     displaystyle = "<xsl:value-of select='gallery-display-style-uuid'/>",
}
   </xsl:for-each>
return t
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.gallery = xsltheader .. [=====[
  <xsl:template match='/reply/gallery'>
LrDate = import 'LrDate'
local PhotoDeckUtils = require 'PhotoDeckUtils'

local t = {
     fullurlpath = "<xsl:value-of select='full-url-path'/>",
     name = [====[<xsl:value-of select='name'/>]====],
     uuid = "<xsl:value-of select='uuid'/>",
     description = [====[<xsl:value-of select='description'/>]====],
     urlpath = "<xsl:value-of select='url-path'/>",
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
     publishedat = PhotoDeckUtils.XMLDateTimeToCoca("<xsl:value-of select='published-at'/>"),
     displaystyle = "<xsl:value-of select='gallery-display-style-uuid'/>",
}
return t
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.media = xsltheader .. [=====[
  <xsl:template match='/reply/media'>
local t = {
  uuid = "<xsl:value-of select='uuid'/>",
<xsl:if test="file-name">
  filename = [====[<xsl:value-of select='file-name'/>]====],
</xsl:if>
<xsl:if test="title">
  title = [====[<xsl:value-of select='title'/>]====],
</xsl:if>
<xsl:if test="file-name">
  description = [====[<xsl:value-of select='description'/>]====],
</xsl:if>
<xsl:if test="keywords">
  <xsl:apply-templates select='keywords'/>
</xsl:if>
<xsl:if test="galleries">
  <xsl:apply-templates select='galleries'/>
</xsl:if>
}
<xsl:if test="upload-location">
  t.uploadlocation = "<xsl:value-of select='upload-location'/>"
</xsl:if>
<xsl:if test="upload-url">
  t.uploadurl = "<xsl:value-of select='upload-url'/>"
</xsl:if>
<xsl:if test="upload-file-param">
  t.uploadfileparam = "<xsl:value-of select='upload-file-param'/>"
</xsl:if>
<xsl:if test="upload-params">
  t.uploadparams = {}
  <xsl:for-each select='upload-params/*'>
  t.uploadparams["<xsl:value-of select='name()'/>"] = [====[<xsl:value-of select='.'/>]====]
  </xsl:for-each>
</xsl:if>
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
    [====[<xsl:value-of select='.'/>]====],
    </xsl:for-each>
  },
  </xsl:template>
]=====] .. xsltfooter


PhotoDeckAPIXSLT.mediasInGallery = xsltheader .. [=====[
  <xsl:template match='/reply/gallery/*'/>
  <xsl:template match='/reply/gallery/medias'>
local t = {
    <xsl:for-each select='media'>
    "<xsl:value-of select='uuid'/>",
   </xsl:for-each>
}
return t
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.subGalleriesInGallery = xsltheader .. [=====[
  <xsl:template match='/reply/galleries'>
local t = {}
    <xsl:for-each select='gallery'>
t["<xsl:value-of select='uuid'/>"] = {
     name = [====[<xsl:value-of select='name'/>]====],
     parentuuid = "<xsl:value-of select='parent-uuid'/>",
     subgalleriescount = "<xsl:value-of select='subgalleries-count'/>",
     page = "<xsl:value-of select='page'/>",
     totalpages = "<xsl:value-of select='total-pages'/>"
}
    </xsl:for-each>
return t
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.totalPages = xsltheader .. [=====[
  <xsl:template match='/reply'>
return "<xsl:value-of select='total-pages'/>"
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.uploadStopWithError = xsltheader .. [=====[
  <xsl:template match='/reply'>
return "<xsl:value-of select='stop-with-error'/>"
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.galleryDisplayStyles = xsltheader .. [=====[
  <xsl:template match='/reply/gallery-display-styles'>
local t = {}
    <xsl:for-each select='gallery-display-style'>
t["<xsl:value-of select='uuid'/>"] = {
     uuid = "<xsl:value-of select='uuid'/>",
     name = [====[<xsl:value-of select='name'/>]====],
}
   </xsl:for-each>
return t
  </xsl:template>
]=====] .. xsltfooter

PhotoDeckAPIXSLT.transform = function(xmlstring, xslt)
  if xmlstring and string.sub(xmlstring, 1, 5) == '<?xml' then
    -- prevent LUA code injection
    local _
    xmlstring, _ = string.gsub(xmlstring, '%[====%[', '')
    xmlstring, _ = string.gsub(xmlstring, '%]====%]', '')

    -- parse & load
    --logger:trace("XML: " .. xmlstring)
    local xml = LrXml.parseXml(xmlstring)
    local luastring = xml:transform(xslt)
    --logger:trace("LUA: " .. luastring)
    if luastring ~= '' then
      local f = assert(loadstring(luastring))
      return f()
    else
      logger:trace(xmlstring)
    end
  end
end

return PhotoDeckAPIXSLT
