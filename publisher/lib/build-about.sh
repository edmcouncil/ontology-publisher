#!/usr/bin/env bash
#
# Create an about file in RDF/XML format, do this BEFORE we convert all .rdf files to the other
# formats so that this about file will also be converted.
#
# TODO: Generate this at each directory level in the tree
#  I don't think this is correct; the About files at lower levels have curated metadata in them.  -DA
#
# DONE: Should be done for each serialization format
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source _functions.sh

function ontologyCreateAboutFiles () {

    # The name of these files has been changed to "All" instead of "About"
    
  require TMPDIR || return $?
  require tag_root || return $?

  logRule "Step: ontologyCreateAboutFiles"

  local -r tmpAboutFileDev="$(createTempFile ABOUTD ttl)"
  local -r tmpAboutFileProd="$(createTempFile ABOUTP ttl)"

  (
    cd "${tag_root:?}" || return $?

    cat > "${tmpAboutFileProd}" << __HERE__
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
@prefix owl: <http://www.w3.org/2002/07/owl#> 
@prefix xsd: <http://www.w3.org/2001/XMLSchema#>
<${tag_root_url}/AboutFIBOProd> a owl:Ontology;
__HERE__

    ${GREP} -r 'utl-av[:;.]Release' . | \
	  ${GREP} -F ".rdf" | \
	  ${SED} 's/:.*$//'  | \
	  while read file; do
	    ${GREP} "xml:base" "${file}";
    done | \
	  ${SED} 's/^.*xml:base="/owl:imports </;s/"[\t \n\r]*$/> ;/' \
	  >> "${tmpAboutFileProd}"

    "${JENA_ARQ}" \
      --data="${tmpAboutFileProd}" \
      --query="${SCRIPT_DIR}/lib/echo.sparql" \
      --results=RDF > "${tag_root}/AboutFIBOProd.rdf" 2> "${TMPDIR}/err.tmp"

    if [ -s "${TMPDIR}/err.tmp" ] ; then
      warning "no RDF XML output generated.  Use AboutFIBOProd.ttl file instead"
    fi
    rm -f "${TMPDIR}/err.tmp"
  )

  (
    cd "${tag_root}" || return $?

    cat > "${tmpAboutFileDev}" << __HERE__
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
@prefix owl: <http://www.w3.org/2002/07/owl#> 
@prefix xsd: <http://www.w3.org/2001/XMLSchema#>
<${tag_root_url}/AboutFIBODev> a owl:Ontology;
__HERE__

    ${GREP} \
      -r "xml:base" \
      $( \
        find . -mindepth 1  -maxdepth 1 -type d -print | \
        ${GREP} -vE "(etc)|(git)"
      ) | \
      ${GREP} -vE "(catalog)|(About)|(About)" | \
	  ${SED} 's/^.*xml:base="/owl:imports </;s/"[ 	\n\r]*$/> ;/' \
      >> "${tmpAboutFileDev}"

    "${JENA_ARQ}" \
      --data="${tmpAboutFileDev}" \
      --query="${SCRIPT_DIR}/lib/echo.sparql" \
      --results=RDF > "${tag_root}/AboutFIBODev.rdf" 2> "${TMPDIR}/err.tmp"

    if [ -s "${TMPDIR}/err.tmp" ] ; then
      warning "no RDF XML output generated.  Use AboutFIBODev.ttl file instead"
    fi
    rm "${TMPDIR}/err.tmp"
  )

  rm -f "${tmpAboutFileDev}"
  rm -f "${tmpAboutFileProd}"

  return 0
}
