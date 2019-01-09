<?xml version="1.0" encoding="UTF-8"?>
  <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:skos="http://www.w3.org/2004/02/skos/core#"
    xmlns:dct="http://purl.org/dc/terms/"
    xmlns:sm="http://www.omg.org/techprocess/ab/SpecificationMetadata/" 
    xmlns:xsd ="http://www.w3.org/2001/XMLSchema#"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fibo-fnd-utl-av="https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/"
    extension-element-prefixes="rdf rdfs owl skos dct sm fibo-fnd-utl-av "
    >
    
    <!-- This file is copyright 2018, Adaptive Inc.  -->
    <!-- All rights reserved. -->
    <!-- A limited license is provided to use and modify this file purely for the purpose of publishing FIBO to publicly accessible sites -->
    <!-- IT MAY NOT, IN WHOLE OR PART, BE USED, COPIED, DISTRIBUTED, MODIFIED OR USED AS THE BASIS OF ANY DERIVED WORK OR 
     FOR ANY OTHER PURPOSE -->
    <!-- To license for any other purpose, please contact info@adaptive.com -->
    
    
    <!-- This converts a clean modules RDF/XML file into a CSV file -->
    <!-- It will show domains, modules and ontologies with the abstract and maturity for the latter -->
    
    <xsl:output method="text"  media-type="text/csv"/>

    <xsl:key name="children" match="*[@rdf:about]" use="@rdf:about"/>
    <xsl:variable name="quote">"</xsl:variable>
    <xsl:variable name="apost">'</xsl:variable>
    
    <xsl:template match="/">
      <xsl:value-of select="'Domain,Module,Ontology,Abstract,Maturity&#x0A;'"/>
      <xsl:for-each select="/rdf:RDF/owl:NamedIndividual[rdf:type/@rdf:resource='http://www.omg.org/techprocess/ab/SpecificationMetadata/Specification']">
        <xsl:apply-templates select="key('children', dct:hasPart/@rdf:resource)" mode="child"/>
      </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*" mode="child">
      <xsl:param name="domain"/>
      <xsl:param name="module"/>
      
      <!-- Recurse until leaf -->
      <xsl:choose>
        <xsl:when test="dct:hasPart">
          <xsl:variable name="domain">
            <xsl:choose>
              <xsl:when test="ends-with(@rdf:about, 'Domain')">
                <xsl:value-of select="rdfs:label"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="$domain"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          <xsl:variable name="module">
            <xsl:choose>
              <xsl:when test="ends-with(rdf:type/@rdf:resource, 'Module')">
                <xsl:value-of select="rdfs:label"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="$module"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          <xsl:apply-templates select="key('children', dct:hasPart/@rdf:resource)" mode="child">
            <xsl:with-param name="domain" select="$domain"/>
            <xsl:with-param name="module" select="$module"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="abstract" select="concat('&quot;', translate(dct:abstract, $quote, $apost), '&quot;')"/>
          <xsl:variable name="maturity">
            <xsl:choose>
              <xsl:when test="contains(name(), 'Ontology')">
                <xsl:variable name="rawMaturity" select="substring-after(fibo-fnd-utl-av:hasMaturityLevel/@rdf:resource, 'https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/')"/>
                <xsl:choose>
                  <xsl:when test="$rawMaturity='Release'">Production</xsl:when>
                  <xsl:when test="$rawMaturity='Provisional'">Development</xsl:when>
                  <xsl:when test="$rawMaturity='Informative'">Development</xsl:when>
                </xsl:choose>
              </xsl:when>
              <xsl:otherwise></xsl:otherwise>
            </xsl:choose>
          </xsl:variable> 
          <xsl:value-of select="concat($domain, ',',  $module, ',', rdfs:label, ',', $abstract, ',', $maturity, '&#x0A;' )"/>
          
        </xsl:otherwise>
      </xsl:choose>
      
     </xsl:template>
    
    <xsl:template match="*" priority="-2"/>
    

            
</xsl:stylesheet>