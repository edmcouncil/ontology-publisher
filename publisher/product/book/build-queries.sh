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

#
# Execute the "list of classes" query
#
function bookQueryListOfClasses() {

  logRule "Step: bookQueryListOfClasses"

  cat > "${TMPDIR}/book-list-of-classes.sq" << __HERE__
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
$(grep --no-filename -r '<!ENTITY' /input/* | sort -u | sed 's/.*<!ENTITY \(.*\) "\(.*\)">/("\1:" <\2>)/g')
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

  logItem "Executing query" "${TMPDIR}/book-list-of-classes.sq"
  tdb2.tdbquery \
    --loc="${book_latex_dir}/tdb2" \
    --query="${TMPDIR}/book-list-of-classes.sq" \
    --results=TSV > "${book_latex_dir}/data/list-of-classes.tsv"
  rc=$?
  logItem "Finished query" "${TMPDIR}/book-list-of-classes.sq"
  logItem "Results in" "${book_latex_dir}/data/list-of-classes.tsv"

  if ((rc > 0)) ; then
    logVar rc
    return ${rc}
  fi

  return 0
}

#
# Execute the "list of super classes" query
#
function bookQueryListOfSuperClasses() {

  logRule "Step: bookQueryListOfSuperClasses"

  cat > "${TMPDIR}/book-list-of-super-classes.sq" << __HERE__
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
$(grep --no-filename -r '<!ENTITY' /input/* | sort -u | sed 's/.*<!ENTITY \(.*\) "\(.*\)">/("\1:" <\2>)/g')
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

  logItem "Executing query" "${TMPDIR}/book-list-of-super-classes.sq"
  tdb2.tdbquery \
    --loc="${book_latex_dir}/tdb2" \
    --query="${TMPDIR}/book-list-of-super-classes.sq" \
    --results=TSV > "${book_latex_dir}/data/list-of-super-classes.tsv"
  rc=$?
  logItem "Finished query" "${TMPDIR}/book-list-of-super-classes.sq"
  logItem "Results in" "${book_latex_dir}/data/list-of-super-classes.tsv"

  if ((rc > 0)) ; then
    logVar rc
    return ${rc}
  fi

  return 0
}
