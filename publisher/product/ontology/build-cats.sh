#!/usr/bin/env bash
#
# Stuff for building catalog files for products like Protegé and Jena
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



function ontologyBuildCatalogs() {

  logStep "ontologyBuildCatalogs"

  ontologyBuildProtegeCatalogs
}
