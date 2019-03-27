#!/usr/bin/env bash
#
# Create a Load file in RDF/XML format, do this BEFORE we convert all .rdf files to the other
# formats so that this load file will also be converted.
#
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

function ontologyCreateAboutFiles () {

    # The name of these files has been changed to "All" instead of "About"
    
  require TMPDIR || return $?
  require tag_root || return $?

  logStep "ontologyCreateAboutFiles"

  local -r tmpAboutFileDev="$(createTempFile ABOUTD ttl)"
  local -r tmpAboutFileProd="$(createTempFile ABOUTP ttl)"

  echo "temp about file dev"
  echo "${tmpAboutFileDev}"

  (
    cd "${tag_root:?}" || return $?

    cat > "${tmpAboutFileProd}" << __HERE__
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
@prefix owl: <http://www.w3.org/2002/07/owl#> 
@prefix xsd: <http://www.w3.org/2001/XMLSchema#>
<${tag_root_url}/LoadFIBOProd> a owl:Ontology;
__HERE__

    ${GREP} -r 'utl-av[:;.]Release' . | \
	  ${GREP} -F ".rdf" | \
	  ${SED} 's/:.*$//'  | \
	  while read file; do
	    ${GREP} "versionIRI" "${file}";
    done | \
	  ${SED} 's/^.*versionIRI.*resource="/owl:imports </;s/".*$/> ;/' \
	  >> "${tmpAboutFileProd}"
    
    "${JENA_ARQ}" \
      --data="${tmpAboutFileProd}" \
      --query="${SCRIPT_DIR}/lib/echo.sparql" \
      --results=RDF > "${tag_root}/LoadFIBOProd.rdf"
    # 2> "${TMPDIR}/err.tmp"

    if [ -s "${TMPDIR}/err.tmp" ] ; then
      warning "no RDF XML output generated.  Use LoadFIBOProd.ttl file instead"
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
<${tag_root_url}/LoadFIBODev> a owl:Ontology;
__HERE__

    ${GREP} \
      -r "versionIRI" \
      $( \
        find . -mindepth 1  -maxdepth 1 -type d -print | \
        ${GREP} -vE "(etc)|(git)"
      ) | \
      ${GREP} -vE "(catalog)|(All)|(About)|(Metadata)" | \
      ${GREP} "rdf" | \
	  ${SED} 's/^.*versionIRI.*resource="/owl:imports </;s/".*$/> ;/' \
      >> "${tmpAboutFileDev}"

    ls -la "${tmpAboutFileDev}"
    cat "${tmpAboutFileDev}"

    
    "${JENA_ARQ}" \
      --data="${tmpAboutFileDev}" \
      --query="${SCRIPT_DIR}/lib/echo.sparql" \
      --results=RDF > "${tag_root}/LoadFIBODev.rdf" 2> "${TMPDIR}/err.tmp"

    if [ -s "${TMPDIR}/err.tmp" ] ; then
      warning "no RDF XML output generated.  Use LoadFIBODev.ttl file instead"
    fi
    rm "${TMPDIR}/err.tmp"
  )

#  rm -f "${tmpAboutFileDev}"
#  rm -f "${tmpAboutFileProd}"

  return 0
}
