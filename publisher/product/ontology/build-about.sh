#!/usr/bin/env bash
#
# Create a Load file in RDF/XML format, do this BEFORE we convert all .rdf files to the other
# formats so that this load file will also be converted.
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source "$(dirname "$(realpath "${0}")")"/../../lib/_functions.sh

function ontologyCreateAboutFiles () {

  require TMPDIR || return $?
  require tag_root || return $?

  logStep "ontologyCreateAboutFiles"

  local -r tmpAboutFileDev="$(createTempFile ABOUTD ttl)"
  local -r tmpAboutFileProd="$(createTempFile ABOUTP ttl)"

  rm -f "${TMPDIR}/err.tmp"

  # use "owl:imports" from ${PROD_SPEC} if exists
  test -n "${PROD_SPEC}" && test -r "${tag_root:?}/${PROD_SPEC}" && (
    cd "${tag_root:?}" || return $?

    logItem "<owl:imports> from \"${PROD_SPEC}\"$(echo -en '\t')" "$(logFileName "${tag_root}/Load${ONTPUB_FAMILY^^}Prod.rdf")"

    cat > "${tmpAboutFileProd}" << __HERE__
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
@prefix owl: <http://www.w3.org/2002/07/owl#> 
@prefix xsd: <http://www.w3.org/2001/XMLSchema#>
<${tag_root_url}/Load${ONTPUB_FAMILY^^}Prod/> a owl:Ontology;
__HERE__

    getOwlImports < "${tag_root}/${PROD_SPEC}" 2>/dev/null | \
	  ${SED} 's/^\(.*\)$/owl:imports <\1> ;/g' \
	  >> "${tmpAboutFileProd}"
    
    "${JENA_ARQ}" \
      --data="${tmpAboutFileProd}" \
      --query="${SCRIPT_DIR}/lib/echo.sparql" \
      --results=RDF > "${tag_root}/Load${ONTPUB_FAMILY^^}Prod.rdf" 2> "${TMPDIR}/err.tmp"

    if [ -s "${TMPDIR}/err.tmp" ] ; then
      warning "no RDF XML output generated.  Use Load${ONTPUB_FAMILY^^}Prod.ttl file instead"
    fi
    rm -f "${TMPDIR}/err.tmp"
  )

  # use "owl:imports" from ${DEV_SPEC} if exists
  test -n "${DEV_SPEC}" && test -r "${tag_root:?}/${PROD_SPEC}" && (
    cd "${tag_root}" || return $?

    logItem "<owl:imports> from \"${DEV_SPEC}\"$(echo -en '\t')" "$(logFileName "${tag_root}/Load${ONTPUB_FAMILY^^}Dev.rdf")"

    cat > "${tmpAboutFileDev}" << __HERE__
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
@prefix owl: <http://www.w3.org/2002/07/owl#> 
@prefix xsd: <http://www.w3.org/2001/XMLSchema#>
<${tag_root_url}/Load${ONTPUB_FAMILY^^}Dev/> a owl:Ontology;
__HERE__

    getOwlImports < "${tag_root}/${DEV_SPEC}" 2>/dev/null | \
	  ${SED} 's/^\(.*\)$/owl:imports <\1> ;/g' \
      >> "${tmpAboutFileDev}"

    "${JENA_ARQ}" \
      --data="${tmpAboutFileDev}" \
      --query="${SCRIPT_DIR}/lib/echo.sparql" \
      --results=RDF > "${tag_root}/Load${ONTPUB_FAMILY^^}Dev.rdf" 2> "${TMPDIR}/err.tmp"

    if [ -s "${TMPDIR}/err.tmp" ] ; then
      warning "no RDF XML output generated.  Use Load${ONTPUB_FAMILY^^}Dev.ttl file instead"
    fi
    rm -f "${TMPDIR}/err.tmp"
  )

  rm -f "${tmpAboutFileDev}"
  rm -f "${tmpAboutFileProd}"

  return 0
}
