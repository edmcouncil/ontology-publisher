#!/usr/bin/env bash
#
# Generate the database, the queries and execute the queries for the book
#
# Copyright (c) agnos.ai UK Ltd, 2018
# Author Jacobus Geluk
# Licensed under MIT License

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

export SCRIPT_DIR="${SCRIPT_DIR}" # Yet another hack to silence IntelliJ
export speedy="${speedy:-0}"

function referenceGenerateTdb2Database() {

  ((reference_skip_content)) && return 0

  logStep "referenceGenerateTdb2Database"

  requireValue reference_latex_dir || return $?
  requireValue ontology_product_tag_root || return $?

#  if [[ -d "${reference_latex_dir}/tdb2" ]] ; then
#    warning "Skipping recreation of ${reference_latex_dir}/tdb2"
#    return 0
#  fi

  if ! which tdb2.tdbloader >/dev/null 2>&1 ; then
    error "jena tdb2.tdbloader is not in the PATH"
    return 1
  fi

  tdb2.tdbloader \
    --loc="${reference_latex_dir}/tdb2" \
    --loader="phased" \
    --verbose \
    $(getDevOntologies)
}

function referenceGeneratePrefixesAsSparqlValues() {

  ((reference_skip_content)) && return 0

  logStep "referenceGeneratePrefixesAsSparqlValues"

#  if [[ -f "${TMPDIR}/reference-prefixes.txt" ]] ; then
#    warning "Skipping recreation of ${TMPDIR}/reference-prefixes.txt"
#    return 0
#  fi

  grep --no-filename -r '<!ENTITY' ${INPUT}/* | \
  grep -v "http://www.omg.org/spec/EDMC-FIBO" | \
  sort -u | \
  sed 's/.*<!ENTITY \(.*\) "\(.*\)">/("\1:" <\2>)/g' > \
  "${TMPDIR}/reference-prefixes.txt"

  return 0
}

#
# Create the SPARQL query file that gets all classes
# Sets two variables:
#
# - reference_query_file_classes
# - reference_results_file_classes
#
function referenceCreateQueryClasses() {

  cat > "${reference_query_file_classes}" << __HERE__
#
# Get a list of all the class names
#
PREFIX afn: <http://jena.apache.org/ARQ/function#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-namespace#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX fibo-fnd-utl-av: <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/>

SELECT DISTINCT
  (STR(?classIRI) AS ?clazz)
  (group_concat(?prefixedName ; separator = "") AS ?prefName)
  ?namezpace
  (STR(?classLabel) AS ?clazzLabel)
  (STR(?definition) AS ?definitionStr)
  (STR(?explanatoryNote) AS ?explanatoryNoteStr)
WHERE {
  #
  # Here's a section with values, one for each prefix / namespace pair
  #
  # TODO: We should just store this in the database itself using the vann ontology or so (http://vocab.org/vann/)
  #
  VALUES (?prefix ?namespace) {
    $(< "${TMPDIR}/reference-prefixes.txt")
    ( "ex1:" <http://example1.com/> )
    ( "ex2:" <http://example2.com/> )
    ( "ex3:" <http://example3.com/> )
  }
  #
  # Now select all the classes in the database
  #
  ?classIRI a owl:Class .
  #
  # Optionally get the english label
  #
  OPTIONAL {
    ?classIRI rdfs:label ?classLabel .
#   FILTER (lang(?classLabel) = 'en')
  }
  #
  # Optionally get the english definition
  #
  OPTIONAL {
    ?classIRI skos:definition ?definition .
#   FILTER (lang(?definition) = 'en')
  }
  #
  # Optionally get the english explanatory note
  #
  OPTIONAL {
    ?classIRI fibo-fnd-utl-av:explanatoryNote ?explanatoryNote .
    FILTER (lang(?explanatoryNote) = 'en')
  }
  #
  # And construct the prefixed version of their names
  #
  BIND(
    IF(
      STRSTARTS(STR(?classIRI), STR(?namespace)),
      CONCAT(
        ?prefix,
        STRAFTER(STR(?classIRI), STR(?namespace))
      ),
      ""
    )
    AS ?prefixedName
  )
  BIND(
    IF(
      STRSTARTS(STR(?classIRI), STR(?namespace)),
      STR(?namespace),
      ""
    )
    AS ?namezpace
  )
  FILTER(?prefixedName != "")
  FILTER(?namezpace != "")
}
#GROUP BY ?classIRI ?classLabel ?namespace ?definition
GROUP BY ?classIRI ?namezpace ?classLabel ?definition ?explanatoryNote
ORDER BY ?classIRI
__HERE__

  local -r checksum="$(md5sum "${reference_query_file_classes}" | cut -f1 -d\  )"

  reference_results_file_classes="${reference_data_dir}/classes-${checksum}.tsv"

  if [[ -f "${reference_results_file_classes}" ]] ; then
    reference_results_file_number_of_classes="$(cat "${reference_results_file_classes}" | wc -l)"
    logItem "Number of classes" ${reference_results_file_number_of_classes}
    referenceExecuteQueryClassesInitArray
    return $?
  fi

  return 1
}

#
# Execute the "list of classes" query
#
function referenceExecuteQueryClasses() {

  if ((reference_skip_content)) ; then
    log "No need to execute the query that gets all classes since we're skipping the actual content"
    return 0
  fi

  logReferenceStep "referenceExecuteQueryClasses"

  referenceCreateQueryClasses && return 0

  logReferenceStep "referenceExecuteQueryClasses"

  #
  # Get the list of classes and some details per class, somehow the DISTINCT keyword
  # doesn't work in the query since it can end up with some duplicate classes if there
  # are multiple solutions for ?definition such as is the case for fibo-fnd-ptyx-prc:RelationshipContext.
  # So we're now just using the brute force way of doing a "sort --unique" (on just the classIRI) to
  # ensure that we only have one line per class.
  #
  logItem "Executing query" "${reference_query_file_classes}"
  tdb2.tdbquery \
    --loc="${reference_latex_dir}/tdb2" \
    --query="${reference_query_file_classes}" \
    --results=TSV | \
    (read -r line; printf "%s\n" "${line}"; sort --key=1,2 --unique) | \
    ${SED} 's/\(^\|\t\)\t/\1 \t/g' \
    > "${reference_results_file_classes}"
  rc=$?
  logItem "Finished query" "${reference_query_file_classes}"
  logItem "Results in"     "${reference_results_file_classes}"

  if ((rc > 0)) ; then
    logVar rc
    return ${rc}
  fi

  reference_results_file_number_of_classes="$(cat "${reference_results_file_classes}" | wc -l)"
  logItem "Number of classes" ${reference_results_file_number_of_classes}

  if [[ ${reference_results_file_number_of_classes} -lt 1 ]] ; then
    error "${reference_results_file_classes} is empty"
    return 1
  fi

  return $?
}

function referenceExecuteQueryClassesInitArray() {

  [[ ${#reference_array_classes[*]} -gt 0 ]] && return 0

  logReferenceStep "referenceExecuteQueryClassesInitArray (should take less than 40 seconds)"

  while IFS=$'\t' read -a line ; do

    [[ "${line[0]}" == "" ]] && continue
    [[ "${line[1]}" == "" ]] && continue
    [[ "${line[0]:0:1}" == "?" ]] && continue

    classIRI="$(stripQuotes "${line[0]}")"
    classPrefName="$(stripQuotes "${line[1]}")"
    namespace="$(stripQuotes "${line[2]}")"
    classLabel="$(stripQuotes "${line[3]}")"
    definition="$(stripQuotes "${line[4]}")"
    explanatoryNote="$(stripQuotes "${line[5]}")"

    reference_array_classes[${classIRI},prefName]="${classPrefName}"
    reference_array_classes[${classIRI},namespace]="${namespace}"
    reference_array_classes[${classIRI},label]="${classLabel}"
    reference_array_classes[${classIRI},definition]="${definition}"
    reference_array_classes[${classIRI},explanatoryNote]="${explanatoryNote}"

  done < "${reference_results_file_classes}"

  logItem "Number of classes" ${reference_results_file_number_of_classes}

  classIRI="http://www.w3.org/2004/02/skos/core#Concept"

  #echo "test: prefName=[${reference_array_classes[${classIRI},prefName]}]"

  return 0
}

#
# Create the SPARQL query file that gets all superclasses
# Sets two variables:
#
# - reference_query_file_superclasses
# - reference_results_file_superclasses
#
function referenceCreateQuerySuperClasses() {

  ((reference_results_file_number_of_superclasses > 0)) && return 0

  cat > "${reference_query_file_superclasses}" << __HERE__
#
# Get a list of all the class IRIs and their super class IRIs
#
PREFIX afn: <http://jena.apache.org/ARQ/function#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-namespace#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX fibo-fnd-utl-av: <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/>

SELECT
  (STR(?classIRI) AS ?class)
  (STR(?superClassIRI) AS ?superClass)
  (group_concat(?superClassPrefixedName ; separator = "") AS ?superClassPrefName)
  ?superClassNamespace
WHERE {
  #
  # Here's a section with values, one for each prefix / namespace pair
  #
  # TODO: We should just store this in the database itself using the vann ontology or so (http://vocab.org/vann/)
  #
  VALUES (?prefix ?namespace) {
    $(< "${TMPDIR}/reference-prefixes.txt")
    ( "ex1:" <http://example1.com/> )
    ( "ex2:" <http://example2.com/> )
    ( "ex3:" <http://example3.com/> )
  }
  #
  # Now select all the classes in the database
  #
  ?classIRI a owl:Class .
  ?classIRI rdfs:subClassOf ?superClassIRI .
  #
  # And construct the prefixed version of their names
  #
  BIND(
    IF(
      STRSTARTS(STR(?superClassIRI), STR(?namespace)),
      CONCAT(
        ?prefix,
        STRAFTER(STR(?superClassIRI), STR(?namespace))
      ),
      ""
    )
    AS ?superClassPrefixedName
  )
  BIND(
    IF(
      STRSTARTS(STR(?superClassIRI), STR(?namespace)),
      STR(?namespace),
      ""
    )
    AS ?superClassNamespace
  )
  FILTER(?superClassPrefixedName != "")
  FILTER(?superClassNamespace != "")
}
GROUP BY ?classIRI ?superClassIRI ?superClassNamespace
ORDER BY ?classIRI ?superClassIRI
__HERE__

  local -r checksum="$(md5sum "${reference_query_file_superclasses}" | cut -f1 -d\  )"

  reference_results_file_superclasses="${reference_data_dir}/superclasses-${checksum}.tsv"

  if [[ -f "${reference_results_file_superclasses}" ]] ; then
    reference_results_file_number_of_superclasses="$(cat "${reference_results_file_superclasses}" | wc -l)"
    logItem "Number of superclasses (1)" ${reference_results_file_number_of_superclasses}
    return 0
  fi

  return 1
}

#
# Execute the "list of super classes" query
#
function referenceExecuteQuerySuperClasses() {

  referenceCreateQuerySuperClasses && return 0

  logReferenceStep "referenceExecuteQuerySuperClasses"

  logItem "Executing query" "${reference_query_file_superclasses}"
  tdb2.tdbquery \
    --loc="${reference_latex_dir:?}/tdb2" \
    --query="${reference_query_file_superclasses}" \
    --results=TSV | ${SED} 's/\(^\|\t\)\t/\1 \t/g' > "${reference_results_file_superclasses}"
  rc=$?
  logItem "Finished query"  "${reference_query_file_superclasses}"
  logItem "Results in"      "${reference_results_file_superclasses}"

  if ((rc > 0)) ; then
    logVar rc
    return ${rc}
  fi

  reference_results_file_number_of_superclasses="$(cat "${reference_results_file_superclasses}" | wc -l)"
  logItem "Number of superclasses (2)" ${reference_results_file_number_of_superclasses}

  if [[ ${reference_results_file_number_of_superclasses} -lt 1 ]] ; then
    error "${reference_results_file_superclasses} is empty"
    return 1
  fi

  return $?
}

#
# Create the SPARQL query file that gets all ontologies
# Sets two variables:
#
# - reference_query_file_ontologies
# - reference_results_file_ontologies
#
function referenceCreateQueryOntologies() {

  cat > "${reference_query_file_ontologies}" << __HERE__
#
# Get a list of all the ontologies
#
PREFIX sm: <http://www.omg.org/techprocess/ab/SpecificationMetadata/>
PREFIX afn: <http://jena.apache.org/ARQ/function#>
PREFIX dct: <http://purl.org/dc/terms/>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-namespace#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX fibo-fnd-utl-av: <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/>

SELECT DISTINCT
  (STR(?ontologyIRI) AS ?ontologyIRIstr)
  (STR(?ontologyVersionIRI) AS ?ontologyVersionIRIstr)
  (STR(?ontologyPrefix) AS ?ontologyPrefixStr)
  (STR(?ontologyLabel) AS ?ontologyLabelStr)
  (STR(?abstract) AS ?abstractStr)
  (STR(?preferredPrefix) AS ?preferredPrefixStr)
  (STR(?maturityLevel) AS ?maturityLevelStr)
WHERE {
  #
  # Here's a section with values, one for each prefix / namespace pair
  #
  # TODO: We should just store this in the database itself using the vann ontology or so (http://vocab.org/vann/)
  #
  VALUES (?prefix ?namespace) {
    $(< "${TMPDIR}/reference-prefixes.txt")
    ( "ex1:" <http://example1.com/> )
    ( "ex2:" <http://example2.com/> )
    ( "ex3:" <http://example3.com/> )
  }
  #
  # Select all the ontologies in the database
  #
  ?ontologyIRI a owl:Ontology .
  #
  # Optionally get the owl:versionIRI
  #
  OPTIONAL {
    ?ontologyIRI owl:versionIRI ?ontologyVersionIRI .
  }
  #
  # Optionally get the english label
  #
  OPTIONAL {
    ?ontologyIRI sm:specificationTitle|dct:title|rdfs:label ?ontologyLabel .
#   FILTER (lang(?ontologyLabel) = 'en')
  }
  #
  # Optionally get the english abstract
  #
  OPTIONAL {
    ?ontologyIRI dct:abstract|sm:specificationAbstract|dct:description ?abstract .
#   FILTER (lang(?abstract) = 'en')
  }
  #
  # Optionally get the preferred prefix (which is strangely enough defined with sm:fileAbbreviation)
  #
  OPTIONAL {
    ?ontologyIRI sm:fileAbbreviation ?preferredPrefix .
  }
  #
  # Optionally get the maturity level
  #
  OPTIONAL {
    ?ontologyIRI fibo-fnd-utl-av:hasMaturityLevel ?maturityLevelIRI .
    ?maturityLevelIRI rdfs:label ?maturityLevel .
  }
  #
  # And construct the prefixed version of the ontology name
  #
  OPTIONAL {
    BIND(
      IF(
        (
          STR(?ontologyIRI) = STR(?namespace)
        ) || (
          CONCAT(STR(?ontologyIRI), "/") = STR(?namespace)
        ) || (
          CONCAT(STR(?ontologyIRI), "#") = STR(?namespace)
        ),
        ?prefix,
        IF(
          BOUND(?preferredPrefix),
          ?preferredPrefix,
          "none"
        )
      )
      AS ?ontologyPrefix
    )
  }
}
ORDER BY ?ontologyIRI
__HERE__

  local -r checksum="$(md5sum "${reference_query_file_ontologies}" | cut -f1 -d\  )"

  reference_results_file_ontologies="${reference_data_dir}/ontologies-${checksum}.tsv"

  if [[ -f "${reference_results_file_ontologies}" ]] ; then
    reference_results_file_number_of_ontologies="$(cat "${reference_results_file_ontologies}" | wc -l)"
    logItem "Number of ontologies" ${reference_results_file_number_of_ontologies}
    referenceExecuteQueryOntologiesInitArray
    return $?
  fi

  return 1
}

#
# Execute the "list of super classes" query
#
function referenceExecuteQueryOntologies() {

  ((reference_skip_content)) && return 0

  referenceCreateQueryOntologies && return 0

  logReferenceStep "referenceExecuteQueryOntologies"

  logItem "Executing query" "${reference_query_file_ontologies}"
  tdb2.tdbquery \
    --loc="${reference_latex_dir:?}/tdb2" \
    --query="${reference_query_file_ontologies}" \
    --results=TSV | ${SED} 's/\(^\|\t\)\t/\1 \t/g' > "${reference_results_file_ontologies}"
  rc=$?
  logItem "Finished query"  "${reference_query_file_ontologies}"
  logItem "Results in"      "${reference_results_file_ontologies}"

  if ((rc > 0)) ; then
    logVar rc
    return ${rc}
  fi

  reference_results_file_number_of_ontologies="$(cat "${reference_results_file_ontologies}" | wc -l)"
  logItem "Number of ontologies" ${reference_results_file_number_of_ontologies}

  if [[ ${reference_results_file_number_of_ontologies} -lt 1 ]] ; then
    error "${reference_results_file_ontologies} is empty"
    return 1
  fi

  return 0
}

function referenceExecuteQueryOntologiesInitArray() {

  [[ ${#reference_array_ontologies[*]} -gt 0 ]] && return 0

  logStep "referenceExecuteQueryOntologiesInitArray (should take less than 40 seconds)"

  while IFS=$'\t' read -a line ; do

    [[ "${line[0]}" == "" ]] && continue
    [[ "${line[1]}" == "" ]] && continue
    [[ "${line[0]:0:1}" == "?" ]] && continue

    ontologyIRI="$(stripQuotes "${line[0]}")"
    ontologyVersionIRI="$(stripQuotes "${line[1]}")"
    prefix="$(stripQuotes "${line[2]}")"
    ontologyLabel="$(stripQuotes "${line[3]}")"
    abstract="$(stripQuotes "${line[4]}")"
    preferredPrefix="$(stripQuotes "${line[5]}")"
    maturityLevel="$(stripQuotes "${line[6]}")"

    reference_array_ontologies[${ontologyIRI},ontologyVersionIRI]="${ontologyVersionIRI}"
    reference_array_ontologies[${ontologyIRI},ontologyLabel]="${ontologyLabel}"
    reference_array_ontologies[${ontologyIRI},prefix]="${prefix}"
    reference_array_ontologies[${ontologyIRI},abstract]="${abstract}"
    reference_array_ontologies[${ontologyIRI},preferredPrefix]="${preferredPrefix}"
    reference_array_ontologies[${ontologyIRI},maturityLevel]="${maturityLevel}"

  done < "${reference_results_file_ontologies}"

  return 0
}