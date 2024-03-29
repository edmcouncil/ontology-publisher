#!/usr/bin/env bash
#
# Invoke the onto-viewer-toolkit to create a "merge-imports" file
#
SCRIPT_DIR="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P)"

if [ -f ${SCRIPT_DIR}/../lib/_functions.sh ] ; then
  # shellcheck source=../lib/_functions.sh
  source ${SCRIPT_DIR}/../lib/_functions.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source ../lib/_functions.sh || exit $?
fi

#
# Invoke the onto-viewer-toolkit to create "merge-imports" file
#
function createMergedFileFrom() {

  local -r rdfFile="$1"             ; requireParameter rdfFile || return $?
  local -r ontologyMappingFile="$2" ; requireParameter ontologyMappingFile || return $?
  local -r infix="$3"               ; requireParameter infix || return $?

  local -r rdfMergedFile="${rdfFile/.rdf}${infix}.rdf"

  local ontologyMergedIRI="$(getOntologyIRI < "${rdfFile}" | sed "s#\(\/\)\?\$#${infix}\1#")"
  local ontologyMergedVersionIRI="$(getOntologyVersionIRI < "${rdfFile}" | sed "s#\(\/\)\?\$#${infix}\1#")"

  logItem "Create merged ontology" "$(logFileName "${ontologyMergedIRI}")"

  local rc=0

  ${ONTOVIEWER_TOOLKIT_JAVA} \
    --goal merge-imports \
    --data "${rdfFile}" $(test -s "${ontologyMappingFile}" && echo "--ontology-mapping \"${ontologyMappingFile}\"") \
    --ontology-iri "${ontologyMergedIRI}" $(test -n "${ontologyMergedVersionIRI}" && echo "--ontology-version-iri \"${ontologyMergedVersionIRI}\"") \
    --output "${rdfMergedFile}" &>/dev/null
  rc=$?

  return ${rc}
}

function main() {

  createMergedFileFrom "$@"
  local -r rc=$?

  ((rc == 0)) && return 0
  error "createMergedFile.sh $@ returned ${rc}"

  return ${rc}
}

main "$@"
exit $?
