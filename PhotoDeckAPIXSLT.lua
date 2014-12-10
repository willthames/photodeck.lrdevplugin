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

return PhotoDeckAPIXSLT
