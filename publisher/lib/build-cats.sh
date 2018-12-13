#!/usr/bin/env bash
#
# Stuff for building catalog files for products like Protegé and Jena (which is needed for SPIN 2.0)
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source _functions.sh

function ontologyBuildProtegeCatalog () {

  local -r directory="$1"
  local -r fibo_rel="$2"

  (
    cd "${directory}" || return $?    # Build the catalog in this directory
    verbose "Building Protegé catalog in $(logFileName "${directory}")"

    cat > catalog-v001.xml << __HERE__
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- Automatically built by the EDMC infrastructure -->
<catalog prefer="public" xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">
__HERE__

    #
    # Find all the rdf files in fibo, and create catalog lines for them based on their location.
    #
    # TODO: Remove hardwired references to fibo and edmcouncil
    #
    find ${fibo_rel} -name '*.rdf' | \
      ${GREP} -v etc | \
      ${SED} 's@^.*$@  <uri id="User Entered Import Resolution" uri="&" name="https://spec.edmcouncil.org/fibo/&"/>@;s@.rdf"/>@/"/>@' | \
      ${SED} "s@fibo/${fibo_rel}/\([a-zA-Z]*/\)@fibo/${product}/${GIT_BRANCH}/${GIT_TAG_NAME}/\U\1\E@" | \
      ${SED} "s@fibo//*@fibo/@g" >> catalog-v001.xml

    cat >> catalog-v001.xml <<< '</catalog>'
  )
}

#
# Generate the Protegé catalog files.
# See also ontologyBuildJenaCatalogs.
#
function ontologyBuildProtegeCatalogs () {

  require tag_root || return $?

  #
  # Run build1catalog in each subdirectory except ext, etc and .git
  #
  find ${tag_root} \
    -maxdepth 1 \
    -mindepth 1 \
    -type d \( \
      -regex "\(.*/ext\)\|\(.*/etc\)\|\(.*/.git\)$" -prune  -o -print \
    \) | while read file ; do
      ontologyIsInTestDomain "${file}" || continue
      ontologyBuildProtegeCatalog "$file" ".." &
    done

  #
  # Run build1catalog in the main directory
  #
  ontologyBuildProtegeCatalog "${tag_root}" "." &

  wait

  return $?
}

#
# Called during the generation of the ontology product.
#
function ontologyBuildJenaCatalogs() {

  require tag_root || return $?

  cat > "${tag_root}/location-mapping.n3" << __HERE__
@prefix lm: <http://jena.hpl.hp.com/2004/08/location-mapping#> .

[] lm:mapping
   [ lm:prefix "${tag_root_url}" ; lm:altPrefix "file:." ] ,
   [ lm:name "file:foo.n3" ;     lm:altName "file:etc/foo.n3" ] ,
   [ lm:prefix "file:etc/" ;     lm:altPrefix "file:ETC/" ] ,
   [ lm:name "file:etc/foo.n3" ; lm:altName "file:DIR/foo.n3" ]
   .
__HERE__

  if ((verbose)) ; then
    log "Generated Jena Location Mapping file:"
    cat "${tag_root}/location-mapping.n3" | pipelog
  fi

  cat > "${tag_root}/ont-policy.rdf" << __HERE__
<?xml version='1.0'?>

<!DOCTYPE rdf:RDF [
    <!ENTITY jena    'http://jena.hpl.hp.com/schemas/'>
    <!ENTITY rdf     'http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
    <!ENTITY rdfs    'http://www.w3.org/2000/01/rdf-schema#'>
    <!ENTITY xsd     'http://www.w3.org/2001/XMLSchema#'>
    <!ENTITY base    '&jena;2003/03/ont-manager'>
    <!ENTITY ont     '&base;#'>
]>

<rdf:RDF
  xmlns:rdf ="&rdf;"
  xmlns:rdfs="&rdfs;"
  xmlns     ="&ont;"
  xml:base  ="&base;"
>
  <DocumentManagerPolicy>
    <!-- policy for controlling the document manager\'s behaviour -->
    <processImports rdf:datatype="&xsd;boolean">false</processImports>
    <cacheModels rdf:datatype="&xsd;boolean">true</cacheModels>
  </DocumentManagerPolicy>

  <OntologySpec>
      <!-- local version of the OWL language ontology (in OWL) -->
      <publicURI rdf:resource="http://www.w3.org/2002/07/owl" />
      <altURL    rdf:resource="file:///publisher/lib/ontologies/owl.owl" />
      <language  rdf:resource="http://www.w3.org/2002/07/owl" />
      <prefix    rdf:datatype="&xsd;string">owl</prefix>
  </OntologySpec>

  <OntologySpec>
      <!-- local version of the RDFS vocabulary -->
      <publicURI rdf:resource="http://www.w3.org/2000/01/rdf-schema" />
      <altURL    rdf:resource="file:///publisher/lib/ontologies/rdf-schema.rdf" />
      <language  rdf:resource="http://www.w3.org/2000/01/rdf-schema" />
      <prefix    rdf:datatype="&xsd;string">rdfs</prefix>
  </OntologySpec>

  <OntologySpec>
      <!-- local version of the spin vocabulary -->
      <publicURI rdf:resource="http://spinrdf.org/spin" />
      <altURL    rdf:resource="file:///publisher/lib/ontologies/spin.rdf" />
  </OntologySpec>

</rdf:RDF>

__HERE__

  if ((verbose)) ; then
    log "Generated Jena Ontology Policy file:"
    cat "${tag_root}/ont-policy.rdf" | pipelog
  fi

  return $?
}

function ontologyBuildCatalogs() {

  logRule "Step: ontologyBuildCatalogs"

  ontologyBuildJenaCatalogs && ontologyBuildProtegeCatalogs
}