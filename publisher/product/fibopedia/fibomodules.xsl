<?xml version='1.0'?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:owl="http://www.w3.org/2002/07/owl#"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:dct="http://purl.org/dc/terms/"
  xmlns:sm="http://www.omg.org/techprocess/ab/SpecificationMetadata/" 
  xmlns:xsd ="http://www.w3.org/2001/XMLSchema#"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fibo-fnd-utl-av="https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/"
  >

  <!-- This file is copyright 2018, Adaptive Inc.  -->
  <!-- All rights reserved. -->
  <!-- A limited license is provided to use and modify this file purely for the purpose of publishing FIBO to publicly accessible sites -->
  <!-- IT MAY NOT, IN WHOLE OR PART, BE USED, COPIED, DISTRIBUTED, MODIFIED OR USED AS THE BASIS OF ANY DERIVED WORK OR 
     FOR ANY OTHER PURPOSE -->
  <!-- To license for any other purpose, please contact info@adaptive.com -->
  

  <!-- This extracts individuals of type sm:Module or sm:Specification from AboutX or MetadataX files
    and builds a RDF file for loading into a triple store without the unnecessary
    Ontologies those files have -->
  <!-- It will recurse through all files from the provided one using dct:hasPart links. --> 
  
  <xsl:output method="xml" indent="yes" media-type="application/xml"/>
  <xsl:strip-space elements="*"/>
  
  <xsl:variable name="base" select="base-uri(/)"/>
  <xsl:variable name="fileterm" select="tokenize($base, '/')[last()]"/>
  <xsl:variable name="filebase" select="substring-before($base, $fileterm)"/>
  
  <xsl:template match="/">
    <rdf:RDF
      xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
      xmlns:owl="http://www.w3.org/2002/07/owl#"
      xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
      xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      xmlns:skos="http://www.w3.org/2004/02/skos/core#"
      xmlns:dct="http://purl.org/dc/terms/"
      xmlns:sm="http://www.omg.org/techprocess/ab/SpecificationMetadata/"
      xmlns:fibo-fnd-utl-av="https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/"
      >
<!--      <xsl:variable name="dir" select="file:parent(document-uri(/))"/> -->
      <xsl:value-of select="'&#x0A;&#x0A;'"/>
      <xsl:comment select="concat('FIBO Module Structure. Generated ', current-dateTime())"/>
      <xsl:value-of select="'&#x0A;&#x0A;'"/>
      <xsl:call-template name="process-mod">
        <xsl:with-param name="mod" select="/rdf:RDF/owl:NamedIndividual"/>
      </xsl:call-template>
    </rdf:RDF>
  </xsl:template>
  
  <xsl:template name="process-mod">
    <xsl:param name="mod"/>
    <!-- Pull out the file that represents any module -->
<!--    <xsl:variable name="metadata-file">
      <xsl:choose>
        <xsl:when test="file:children($dir)[contains(., 'Metadata')]">
          <xsl:value-of select="file:children($dir)[contains(., 'Metadata')][1]"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message select="concat('Warning - no metadata in directory: ', $dir)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="$metadata-file != ''">
      <xsl:variable name="filename" select="file:path-to-uri($metadata-file)"/> -->
<!--      <xsl:message select="concat('Processing file: ', $filename)"/> -->
    <xsl:choose>
      <xsl:when test="$mod/rdf:type/@rdf:resource='http://www.omg.org/techprocess/ab/SpecificationMetadata/Module'">
        <xsl:for-each select="$mod">
          <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
              <xsl:when test="dct:hasPart"/> <!-- No need to do anything it will be copied -->
              <xsl:otherwise>
                <xsl:message select="concat('Assuming following Module is a leaf module: ', @rdf:about)"/>                   
              </xsl:otherwise>
            </xsl:choose>
           <xsl:apply-templates/>
          </xsl:copy>
        </xsl:for-each>
      </xsl:when>
      <xsl:when test="$mod/rdf:type/@rdf:resource='http://www.omg.org/techprocess/ab/SpecificationMetadata/Specification'">
        <!-- legacy except for top level -->
        <xsl:for-each select="$mod">
          <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="rdf:type"/>
            <xsl:if test="sm:specificationAbstract">
              <dct:abstract>
                <xsl:value-of select="sm:specificationAbstract"/>
              </dct:abstract>
            </xsl:if>
            <xsl:if test="sm:specificationTitle">
              <dct:title>
                <xsl:value-of select="sm:specificationTitle"/>
              </dct:title>
            </xsl:if>
            <xsl:apply-templates select="*[not(name()='rdf:type')]"/>
          </xsl:copy>
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>
    <!-- recurse -->
    <xsl:for-each select="$mod/dct:hasPart">
      <xsl:variable name="target" select="@rdf:resource"/>
      <xsl:variable name="domain" select="substring-before(substring-after($target, '/ontology/'), '/')"/>
      <xsl:variable name="term" select="substring-after($target, concat('/ontology/', $domain, '/'))"/>
      <xsl:variable name="last" select="tokenize($term, '/')[last()]"/>
      <!-- Processing differs depending whether we are processing an ontology or a module/domain -->
      <xsl:choose>
        <xsl:when test="ends-with($last, 'Domain') or ends-with($last, 'Module')">
          <!-- for the file we need to ignore the last element -->
          <xsl:variable name="filename" select="concat($filebase, $domain, '/', substring-before($term, concat('/', $last)), '.rdf')"/>
          <!-- <xsl:message select="concat('Processing file: ', $filename)"/> -->       
          <xsl:variable name="rdf" select="document($filename)/rdf:RDF"/>
          <xsl:call-template name="process-mod">
            <xsl:with-param name="mod" select="$rdf/owl:NamedIndividual"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="filename"  select="concat($filebase, $domain, '/', string-join(tokenize($term,'/')[position() != last()],'/'), '.rdf')"/>
          <!-- <xsl:message select="concat('Processing file: ', $filename)"/> -->       
          <xsl:variable name="rdf" select="document($filename)/rdf:RDF"/>
          <xsl:variable name="xmlbase" select="$rdf/@xml:base"/>
          <xsl:variable name="ontology" select="$rdf//owl:Ontology[1]"/>
          <xsl:variable name="ontology-uri" select="$ontology/@rdf:about"/>
          <xsl:for-each select="$rdf/owl:Ontology">
            <!-- For ontologies pull out the maturity, name and abstract -->
            <xsl:copy>
              <xsl:copy-of select="@*"/>
              <xsl:copy-of select="rdfs:label"/>
              <xsl:copy-of select="dct:abstract"/>
              <xsl:if test="not(fibo-fnd-utl-av:hasMaturityLevel)">
                <xsl:message select="concat('Warning ontology ', $ontology/@rdf:about, ' has no maturity level.')"/>                 
              </xsl:if>
              <xsl:copy-of select="fibo-fnd-utl-av:hasMaturityLevel"/>
            </xsl:copy>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  
  <!-- Legacy properties this XSL is replacing or which are not being used any more -->
  <xsl:template match="sm:specificationAbstract"/>
  <xsl:template match="sm:specificationTitle"/>
  <xsl:template match="sm:moduleAbstract"/>
  <xsl:template match="skos:definition"/> <!-- Only used at Ontology level -->
  
  <xsl:template match="*" priority="-1">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>   
  </xsl:template>
  
</xsl:stylesheet>