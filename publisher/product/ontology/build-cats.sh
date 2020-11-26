#!/usr/bin/env bash
#
# Stuff for building catalog files for products like Protegé and Jena (which is needed for SPIN 2.0)
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

function ontologyBuildProtegeCatalog () {

  local -r directory="$1"
  local -r rel_path="$2"

  (
    cd "${directory}" || return $?    # Build the catalog in this directory
    ((verbose)) && logItem "Protegé catalog" "$(logFileName "${directory}")"

    cat > catalog-v001.xml << __HERE__
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- Automatically built by the EDMC infrastructure -->
<catalog prefer="public" xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">
</catalog>
__HERE__

    #
    # Find all the rdf files and create catalog lines for them based on their location.
    #
    cat	<(find "${rel_path}" -type f -name \*\.rdf -print | sort) | while read ontologyRdfFile ; do
     #  is owl:Ontology?
     if isOntology < "${ontologyRdfFile}" ; then
      #
      # get ontology IRI and version IRI
      #
      cat <(getOntologyIRI < "${ontologyRdfFile}") <(getOntologyVersionIRI < "${ontologyRdfFile}") | while read ontologyIRI ; do
       #
       # is ontologyIRI already in "catalog-v001.xml"?
       #
       if ! xml sel -t -c "/_:catalog/_:uri[@name='${ontologyIRI}']" catalog-v001.xml &>/dev/null ; then
        echo -en "."
        xml -q ed -P -L -s '/_:catalog' --type elem -n 'uri' -v "" -a '$prev' --type attr -n 'name' -v "${ontologyIRI}" -a '$prev/..' --type attr -n 'uri' -v "${ontologyRdfFile}" catalog-v001.xml
       else
        echo -en ":"
       fi
      done
     fi
    done
    cat "catalog-v001.xml" | xml fo -s 4 -N > "catalog-v001.xml.tmp" 2>/dev/null && mv -f "catalog-v001.xml.tmp" "catalog-v001.xml"
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

  echo -e '|'

  return $?
}

function makeFileUrl() {

  local -r absolutePath="$1"

  echo -n "file://${absolutePath}"
}

#
# Called during the generation of the ontology product.
#
function ontologyBuildJenaCatalogs() {

  require tag_root || return $?

  cat > "${tag_root}/location-mapping.n3" << __HERE__
@prefix lm: <http://jena.hpl.hp.com/2004/08/location-mapping#> .

[] lm:mapping
  #
  # The lm:prefix/lm:altPrefix construct below does not work because it doesn't replace the last / in the given url
  # with ".rdf" so it cannot actually find the corresponding local file.
  #
  #[
  #  lm:prefix "${tag_root_url}" ;
  #  lm:altPrefix "file://${tag_root}"
  #],
__HERE__

  cat > "${tag_root}/ont-policy.rdf" << __HERE__
<?xml version='1.0'?>

<!DOCTYPE rdf:RDF [
    <!--

    NOTE that we're using the old namespace here for jena, hpl.hp.com, not apache.org.
    See this line:

    https://github.com/apache/jena/blob/69571e7ebc3bfde6ec3bc4e96d136428d7f7378e/
    jena-core/src/main/java/org/apache/jena/vocabulary/OntDocManagerVocab.java#L39

    -->
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
    <!-- policy for controlling the document manager's behaviour -->
    <!--
      Switching the processImports value from false to true will cause tools like SPIN
      to import everything where many ontologies will be downloaded from the web.
      If the "\-\-network none" option is given when starting the container (check docker-run.sh)
      then all these external HTTP GET requests will fail, but nevertheless its important to
      understand the impact of the value below.
    -->
    <processImports rdf:datatype="&xsd;boolean">false</processImports>
    <cacheModels rdf:datatype="&xsd;boolean">true</cacheModels>
  </DocumentManagerPolicy>
</rdf:RDF>
__HERE__

  (
    cd / || return $?
    echo -en "\t"
    #
    # Now read: all our own and LCC ontologies + additional from "/publisher/lib/ontologies/**.rdf"
    #
    cat	<(find "${tag_root}"  -name \*\.rdf -print | sort) \
	<(find "${INPUT}/LCC" -name \*\.rdf -print | sort) \
	<(find "/publisher/lib/ontologies" -name \*\.rdf -print | sort) | while read ontologyRdfFile ; do
     #  is owl:Ontology?
     if isOntology < "${ontologyRdfFile}" ; then
      #
      # get ontology IRI and version IRI
      #
      cat <(getOntologyIRI < "${ontologyRdfFile}") <(getOntologyVersionIRI < "${ontologyRdfFile}") | while read ontologyIRI ; do
       #
       # is ontologyIRI already mapped in "${tag_root}/ont-policy.rdf"?
       #
       if ! xml c14n "${tag_root}/ont-policy.rdf" 2>/dev/null | xml sel -t -c "/rdf:RDF/_:OntologySpec/_:publicURI[@rdf:resource='${ontologyIRI}']" &>/dev/null ; then
        echo -en "."
        cat >> "${tag_root}/location-mapping.n3" << __HERE__
  [
    lm:name "${ontologyIRI}" ;
    lm:altName "$(makeFileUrl ${ontologyRdfFile})"
  ],
__HERE__
        xml -q ed -P -L -s '/rdf:RDF' --type elem -n 'OntologySpec' -v "" \
		-s '$prev'       --type elem -n 'publicURI' -a '$prev' --type attr -n 'rdf:resource' -v "${ontologyIRI}" \
		-s '$prev/../..' --type elem -n 'altURL'    -a '$prev' --type attr -n 'rdf:resource' -v "$(makeFileUrl ${ontologyRdfFile})" \
		-s '$prev/../..' --type elem -n 'language'  -a '$prev' --type attr -n 'rdf:resource' -v "http://www.w3.org/2000/01/rdf-schema" \
		"${tag_root}/ont-policy.rdf" 2>/dev/null
       else
        echo -en ":"
       fi
      done
     fi
    done
    echo -e '|'
  )

  #
  # Remove the last comma
  #
  truncate -s-2 "${tag_root}/location-mapping.n3"

  cat >> "${tag_root}/location-mapping.n3" <<< "."

  # for "http://www.w3.org/2002/07/owl" set language "http://www.w3.org/2002/07/owl" and add prefix "owl"
  # for "http://www.w3.org/2002/07/owl" add prefix "owl"
  # for "http://www.w3.org/2000/01/rdf-schema#" add prefix "rdfs"
  # workaround for '&' + format
  cat "${tag_root}/ont-policy.rdf" | \
    xml -q ed -P -u '/rdf:RDF/_:OntologySpec/_:publicURI[@rdf:resource="http://www.w3.org/2002/07/owl"]/../_:language/@rdf:resource' \
	-v 'http://www.w3.org/2002/07/owl' 2>/dev/null | \
    xml -q ed -P -a '/rdf:RDF/_:OntologySpec/_:publicURI[@rdf:resource="http://www.w3.org/2002/07/owl"]' \
	-t elem -n 'prefix' -v 'owl' -a '$prev' -t attr -n 'rdf:datatype' -v 'xsd:string' 2>/dev/null | \
    xml -q ed -P -a '/rdf:RDF/_:OntologySpec/_:publicURI[@rdf:resource="http://www.w3.org/2000/01/rdf-schema#"]' \
	-t elem -n 'prefix' -v 'rdfs' -a '$prev' -t attr -n 'rdf:datatype' -v 'xsd:string' 2>/dev/null | \
    sed 's#"xsd:#"\&xsd;#g' | xml fo -s 4 -N > "${tag_root}/ont-policy.rdf.tmp" 2>/dev/null && \
    mv -f "${tag_root}/ont-policy.rdf.tmp" "${tag_root}/ont-policy.rdf"

  log "Generated Jena Location Mapping and Jena Ontology Policy files"
#  if ((verbose)) ; then
#    cat "${tag_root}/ont-policy.rdf" | pipelog
#  fi

  return $?
}

function ontologyBuildCatalogs() {

  logStep "ontologyBuildCatalogs"

  find ${OUTPUT} -name 'ont-policy.rdf' -o -name 'location-mapping.n3' -delete

  ontologyBuildJenaCatalogs && ontologyBuildProtegeCatalogs
}
