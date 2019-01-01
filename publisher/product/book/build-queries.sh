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

function bookGenerateTdb2Database() {

  logRule "Step: bookGenerateTdb2Database"

  requireValue book_latex_dir || return $?
  requireValue ontology_product_tag_root || return $?

  if [ -d "${book_latex_dir}/tdb2" ] ; then
    warning "Skipping recreation of ${book_latex_dir}/tdb2"
    return 0
  fi

  tdb2.tdbloader \
    --loc="${book_latex_dir}/tdb2" \
    --loader="phased" \
    --verbose \
    $(${FIND} "${ontology_product_tag_root}" -name "*.rdf")
}

function bookGeneratePrefixesAsSparqlValues() {

  logRule "Step: bookGeneratePrefixesAsSparqlValues"

  if [ -f "${TMPDIR}/book-prefixes.txt" ] ; then
    warning "Skipping recreation of ${TMPDIR}/book-prefixes.txt"
    return 0
  fi

  grep --no-filename -r '<!ENTITY' /input/* | \
  grep -v "http://www.omg.org/spec/EDMC-FIBO" | \
  sort -u | \
  sed 's/.*<!ENTITY \(.*\) "\(.*\)">/("\1:" <\2>)/g' > \
  "${TMPDIR}/book-prefixes.txt"

  return 0
}

function bookCreateQueryListOfClasses() {

  book_query_file="${TMPDIR}/book-list-of-classes.sq"

  cat > "${book_query_file}" << __HERE__
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
    $(< "${TMPDIR}/book-prefixes.txt")
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
    FILTER (lang(?classLabel) = 'en')
  }
  #
  # Optionally get the english definition
  #
  OPTIONAL {
    ?classIRI skos:definition ?definition .
    FILTER (lang(?definition) = 'en')
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

  local -r checksum="$(md5sum "${book_query_file}" | cut -f1 -d\  )"

  book_results_file="${book_latex_dir:?}/data/list-of-classes-${checksum}.tsv"

  return 0

}

#
# Execute the "list of classes" query and store the name of the results file in the caller's variable book_results_file
#
function bookQueryListOfClasses() {

  local book_query_file

  bookCreateQueryListOfClasses || return $?

  #
  # If the results file already exists then it doesn't make sense
  # to run the query again.
  #
  [ -z "${book_results_file}" ] && return 1
  if [ -f "${book_results_file}" ] ; then
    bookQueryListOfClassesInitArray
    return $?
  fi

  logRule "Step: bookQueryListOfClasses"

  #
  # Get the list of classes and some details per class, somehow the DISTINCT keyword
  # doesn't work in the query since it can end up with some duplicate classes if there
  # are multiple solutions for ?definition such as is the case for fibo-fnd-ptyx-prc:RelationshipContext.
  # So we're now just using the brute force way of doing a "sort --unique" (on just the classIRI) to
  # ensure that we only have one line per class.
  #
  logItem "Executing query" "${book_query_file}"
  tdb2.tdbquery \
    --loc="${book_latex_dir}/tdb2" \
    --query="${book_query_file}" \
    --results=TSV | sort --key=1,2 --unique > "${book_results_file}"
  rc=$?
  logItem "Finished query" "${book_query_file}"
  logItem "Results in" "${book_results_file}"

  if ((rc > 0)) ; then
    logVar rc
    return ${rc}
  fi

  return 0
}

function bookQueryListOfClassesInitArray() {

  [ ${#book_array_classes[*]} -gt 0 ] && return 0

  logRule "Step: bookQueryListOfClassesInitArray (should take less than 40 seconds)"

  while IFS=$'\t' read -a line ; do

    [ "${line[0]}" == "" ] && continue
    [ "${line[1]}" == "" ] && continue
    [ "${line[0]:0:1}" == "?" ] && continue

    classIRI="$(stripQuotes "${line[0]}")"
    classPrefName="$(stripQuotes "${line[1]}")"
    namespace="$(stripQuotes "${line[2]}")"
    classLabel="$(stripQuotes "${line[3]}")"
    definition="$(stripQuotes "${line[4]}")"
    explanatoryNote="$(stripQuotes "${line[5]}")"

    book_array_classes[${classIRI},prefName]="${classPrefName}"
    book_array_classes[${classIRI},namespace]="${namespace}"
    book_array_classes[${classIRI},label]="${classLabel}"
    book_array_classes[${classIRI},definition]="${definition}"
    book_array_classes[${classIRI},explanatoryNote]="${explanatoryNote}"

  done < "${book_results_file}"

  log "Step: bookQueryListOfClassesInitArray done"

  classIRI="http://www.w3.org/2004/02/skos/core#Concept"

  #echo "test: prefName=[${book_array_classes[${classIRI},prefName]}]"

  return 0
}
#
# Generates query "list of super classes"
#
# Stores name of query file in global variable book_query_file and
# name of results file in book_results_file
#
function bookCreateQueryListOfSuperClasses() {

  book_query_file="${TMPDIR}/book-list-of-super-classes.sq"

  cat > "${book_query_file}" << __HERE__
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
    $(< "${TMPDIR}/book-prefixes.txt")
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

  local -r checksum="$(md5sum "${book_query_file}" | cut -f1 -d\  )"

  book_results_file="${book_latex_dir:?}/data/list-of-super-classes-${checksum}.tsv"

  return 0
}

#
# Execute the "list of super classes" query
#
function bookQueryListOfSuperClasses() {

  local book_query_file

  bookCreateQueryListOfSuperClasses || return $?

  #
  # If the results file already exists then it doesn't make sense
  # to run the query again.
  #
  [ -z "${book_results_file}" ] && return 1
  [ -f "${book_results_file}" ] && return 0

  logRule "Step: bookQueryListOfSuperClasses"

  logItem "Executing query" "${book_query_file}"
  tdb2.tdbquery \
    --loc="${book_latex_dir:?}/tdb2" \
    --query="${book_query_file}" \
    --results=TSV > "${book_results_file}"
  rc=$?
  logItem "Finished query" "${book_query_file}"
  logItem "Results in" "${book_results_file}"

  if ((rc > 0)) ; then
    logVar rc
    return ${rc}
  fi

  return 0
}
