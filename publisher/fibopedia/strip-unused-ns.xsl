<?xml version="1.0" encoding="UTF-8"?>
  <xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output indent="yes"/>
    <xsl:strip-space elements="*"/>
    
    <!-- Utility XSL to strips out unused namespace declarations. 
      XSL copied from https://stackoverflow.com/questions/4593326/xsl-how-to-remove-unused-namespaces-from-source-xml -->
    
    <xsl:template match="node()|@*" priority="-2">
      <xsl:copy>
        <xsl:apply-templates select="node()|@*"/>
      </xsl:copy>
    </xsl:template>
    
    <xsl:template match="*">
      <xsl:element name="{name()}" namespace="{namespace-uri()}">
        <xsl:variable name="vtheElem" select="."/>
        
        <xsl:for-each select="namespace::*">
          <xsl:variable name="vPrefix" select="name()"/>
          
          <xsl:if test=
            "$vtheElem/descendant::*
            [(namespace-uri()=current()
            and 
            substring-before(name(),':') = $vPrefix)
            or
            @*[substring-before(name(),':') = $vPrefix]
            ]
            ">
            <xsl:copy-of select="."/>
          </xsl:if>
        </xsl:for-each>
        <xsl:apply-templates select="node()|@*"/>
      </xsl:element>
    </xsl:template>
  </xsl:stylesheet>
