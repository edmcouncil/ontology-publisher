<?xml version="1.0" encoding="UTF-8"?>
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
    extension-element-prefixes="rdf rdfs owl skos dct sm fibo-fnd-utl-av "
    >
    
    <!-- This file is copyright 2018, Adaptive Inc.  -->
    <!-- All rights reserved. -->
    <!-- A limited license is provided to use and modify this file purely for the purpose of publishing FIBO to publicly accessible sites -->
    <!-- IT MAY NOT, IN WHOLE OR PART, BE USED, COPIED, DISTRIBUTED, MODIFIED OR USED AS THE BASIS OF ANY DERIVED WORK OR 
     FOR ANY OTHER PURPOSE -->
    <!-- To license for any other purpose, please contact info@adaptive.com -->
    
    
    <!-- This formats a clean modules RDF/XML file for display using Basic Expandble Tree List
       That is covered here https://codepen.io/marcomtr/pen/eJOepz -->
    <!-- It will show modules and ontologies with a tooltip for the abstract, and for the latter link to the widoco page-->
    
    <xsl:output method="html" indent="yes" media-type="text/html"/>
    <xsl:strip-space elements="*"/>

    <xsl:key name="children" match="*[@rdf:about]" use="@rdf:about"/>
    
    <xsl:template match="/">
      <html lang="en" >
        <head>
          <meta charset="UTF-8"/>
            <title>FIBOpedia</title>
<!--            <link rel="stylesheet" href="css/style.css"/> -->
          <xsl:call-template name="license"/>
          <xsl:call-template name="stylesheet"/>
        </head>
        <body>
          <br/>
          <img src="https://spec.edmcouncil.org/static/image/edmc-logo.jpg" height="100"/>
          <br/>
          <h1>FIBOpedia</h1>
          <p>This page allows you to navigate the tree structure of FIBO's Domains and Modules and drill down into the individual ontologies.<br/>
            If you hover the mouse over any item you’ll see its description.<br/> 
            For ontologies (the bottom level) it will tell you the status (either Production or Development) and clicking on one will take you to the web document for that ontology.
            These documents are automatically generated for each ontology using <a href="https://github.com/dgarijo/Widoco">WIzard for DOCumenting Ontologies (WIDOCO)</a> software, 
            which includes a graphical visualization of the ontology and related elements in a force-directed graph layout using <a href="http://vowl.visualdataweb.org/v2/">Visual Notation for OWL Ontologies (VOWL)</a>. 
          </p>
          <p>Note: it has not been possible to generate WIDOCO documents for all the Development ontologies in FIBO (there are currently about 100 missing). 
            Clicking on those ontologies will give you an error page. The FIBO team is working to avoid creating a link in such cases.</p>
          <br/>
          <ul class="tree">
             <xsl:for-each select="/rdf:RDF/owl:NamedIndividual[rdf:type/@rdf:resource='http://www.omg.org/techprocess/ab/SpecificationMetadata/Specification']">
                <li class="tree__item">
                  <span>
                    <a>
                      <xsl:attribute name="href" select="'#'"/>
                      <xsl:value-of select="rdfs:label"/>
                    </a>
                  </span>
                </li>
              <xsl:apply-templates select="key('children', dct:hasPart/@rdf:resource)" mode="child"/>
            </xsl:for-each>
          </ul>
          <script src='https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.3/jquery.min.js'></script>
<!--          <script  src="js/index.js"></script> -->
          <xsl:call-template name="script"/>          
        </body>
      </html>
    </xsl:template>
    
    <xsl:template match="*" mode="child">
      <li>
        <span>
          <xsl:variable name="style">
            <xsl:choose>
              <xsl:when test="contains(name(), 'Ontology')">tree__item</xsl:when>
              <xsl:when test="dct:hasPart">icon hasChildren</xsl:when>
              <xsl:otherwise>tree__item</xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          <div class="{$style}"></div>
          <a>
            <xsl:attribute name="href" >
               <xsl:choose>
                 <xsl:when test="contains(name(), 'Ontology')">
                   <xsl:value-of select="concat(substring-before(@rdf:about, '/ontology/'),
                     '/widoco/master/latest/',substring-after(@rdf:about, '/ontology/'), 'index-en.html')"/>                
                 </xsl:when>
                 <xsl:otherwise>#</xsl:otherwise>
               </xsl:choose>
            </xsl:attribute>
            <xsl:attribute name="title" select="dct:abstract"/>
            <xsl:variable name="maturity">
              <xsl:choose>
                <xsl:when test="contains(name(), 'Ontology')">
                  <xsl:variable name="rawMaturity" select="substring-after(fibo-fnd-utl-av:hasMaturityLevel/@rdf:resource, 'https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/')"/>
                  <xsl:choose>
                    <xsl:when test="$rawMaturity='Release'"> (Production)</xsl:when>
                    <xsl:when test="$rawMaturity='Provisional'"> (Development)</xsl:when>
                    <xsl:when test="$rawMaturity='Informative'"> (Development)</xsl:when>
                    <xsl:otherwise>()</xsl:otherwise>
                  </xsl:choose>
                </xsl:when>
                <xsl:otherwise></xsl:otherwise>
              </xsl:choose>
            </xsl:variable> 
            <xsl:value-of select="concat(rdfs:label, $maturity )"/>
          </a>
        </span>
        <xsl:if test="dct:hasPart">
          <ul>
            <xsl:apply-templates select="key('children', dct:hasPart/@rdf:resource)" mode="child"/>
          </ul>
        </xsl:if>
      </li>      
    </xsl:template>
    
    <xsl:template match="*" priority="-2"/>
    
    <xsl:template name="license">
      <xsl:comment>

This page makes use of Javascript and CSS which subject to the following license: 

Copyright (c) 2018 by Marco Monteiro (https://codepen.io/marcomtr/pen/eJOepz)


Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

      </xsl:comment>
    </xsl:template>
    
    <xsl:template name="stylesheet">
      <style>
      body {
      font-family: Helvetica, sans-serif;
      font-size:15px;
      }
      
      a {
      text-decoration:none;
      }
      ul.tree, .tree li {
      list-style: none;
      margin:0;
      padding:0;
      cursor: pointer;
      }
      
      .tree ul {
      display:none;
      }
      
      .tree > li {
      display:block;
      background:#eee;
      margin-bottom:2px;
      }
      
      .tree span {
      display:block;
      padding:10px 12px;
      
      }
      
      .icon {
      display:inline-block;
      }
      
      .tree .hasChildren > .expanded {
      background:#999;
      }
      
      .tree .hasChildren > .expanded a {
      color:#fff;
      }
      
      .icon:before {
      content:"+";
      display:inline-block;
      min-width:20px;
      text-align:center;
      }
      .tree .icon.expanded:before {
      content:"-";
      }
      
      .show-effect {
      display:block!important;
      }
      </style>
    </xsl:template>
    
    <xsl:template name="script">
      <script>
      $('.tree .icon').click( function() {
      $(this).parent().toggleClass('expanded').
      closest('li').find('ul:first').
      toggleClass('show-effect');
      });
      </script>
    </xsl:template>
            
</xsl:stylesheet>
