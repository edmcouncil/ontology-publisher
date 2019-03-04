#!/usr/bin/env bash
#
# Generate the datadictionary "product" from the source ontologies
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

#
# Produce all artifacts for the datadictionary product
#
# Turns FIBO in to FIBO-V
#
# The translation proceeds with the following steps:
#
# 1) Start the output with the standard prefixes.  They are in a file called skosprefixes.
# 2) Determine which modules will be included. They are kept on a property called <http://www.edmcouncil.org/skosify#module> in skosify.ttl
# 3) Gather up all the RDF files in those modules
# 4) Run the shemify rules.  This adds a ConceptScheme to the output.
# 5) Merge the ConceptScheme triples with the SKOS triples
# 6) Convert upper cases.  We have different naming standards in FIBO-V than in FIBO.
# 7) Remove all temp files.
#
# The output is in .ttl form in a file called fibo-v.ttl
#
function publishProductVocabulary() {

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  require JENAROOT || return $?

  setProduct ontology
  ontology_product_tag_root="${tag_root}"

  setProduct vocabulary || return $?
  vocabulary_product_tag_root="${tag_root}"

  (
    cd "${SCRIPT_DIR}/product/vocabulary" || return $?
    vocabulary_script_dir="$(pwd)"

    publishProductVocabularyInner
  )
  local rc=$?

  log "Done with processing product vocabulary rc=${rc}"

  return ${rc}
}

function publishProductVocabularyInner() {

  #
  # 1) Start the output with the standard prefixes.  We compute these from the files.
  #
  log "# baseURI: ${product_root_url}" > ${TMPDIR}/fibo-v1.ttl
  #cat skosprefixes >> ${TMPDIR}/fibo-v1.ttl

  #vocabularyGetModules || return $?
  vocabularyGetPrefixes || return $?
  vocabularyGetOntologies || return $?
  vocabularyRunSpin || return $?
  vocabularyRunSchemifyRules || return $?

  log "second run of spin"
  "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/temp2.ttl" "${TMPDIR}/tc.ttl" || return $?
  "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/temp2B.ttl" "${TMPDIR}/tcB.ttl" || return $?

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  log "ENDING SPIN"
  #
  # 5) Merge the ConceptScheme triples with the SKOS triples
  #
  ${JENA_ARQ}  \
    --data="${TMPDIR}/tc.ttl" \
    --data="${TMPDIR}/temp1.ttl" \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --results=TTL > "${TMPDIR}/fibo-uc.ttl"

  ${JENA_ARQ}  \
    --data="${TMPDIR}/tcB.ttl" \
    --data="${TMPDIR}/temp1B.ttl" \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --results=TTL > "${TMPDIR}/fibo-ucB.ttl"

  #
  # 6) Convert upper cases.  We have different naming standards in FIBO-V than in FIBO.
  #
  ${SED} "s/uc(\([^)]*\))/\U\1/g" "${TMPDIR}/fibo-uc.ttl" >> ${TMPDIR}/fibo-v1.ttl
  ${SED} "s/uc(\([^)]*\))/\U\1/g" "${TMPDIR}/fibo-ucB.ttl" >> ${TMPDIR}/fibo-v1B.ttl

  ${JENA_ARQ}  \
    --data="${TMPDIR}/fibo-v1.ttl" \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --results=TTL > "${TMPDIR}/fibo-vD.ttl"
  ${JENA_ARQ}  \
    --data="${TMPDIR}/fibo-v1B.ttl" \
    --query="${SCRIPT_DIR}/lib/echo.sparql" \
    --results=TTL > "${TMPDIR}/fibo-vP.ttl"

  #
  # Adjust namespaces
  #
  ${JENA_RIOT} "${TMPDIR}/fibo-vD.ttl" > "${TMPDIR}/fibo-vD.nt"
  ${JENA_RIOT} "${TMPDIR}/fibo-vP.ttl" > "${TMPDIR}/fibo-vP.nt"

  cat > "${TMPDIR}/vochelp.ttl" <<EOF
  <${spec_root_url}/fibo/vocabulary#hasDomain>
  rdf:type owl:AnnotationProperty ;
  rdfs:label "has domain" ;
  rdfs:range xsd:string ;
  rdfs:subPropertyOf dct:subject .
  <${spec_root_url}/fibo/vocabulary#hasSubDomain>
  rdf:type owl:AnnotationProperty ;
  rdfs:label "has subdomain" ;
  rdfs:range xsd:string ;
  rdfs:subPropertyOf dct:subject .
EOF

  cat \
    "${TMPDIR}/prefixes.ttl" \
    "${TMPDIR}/vochelp.ttl" \
    "${TMPDIR}/fibo-vD.nt" | \
  ${JENA_RIOT} \
    --syntax=turtle \
    --output=turtle > \
    "${tag_root}/fibo-vD.ttl"

  cat \
    "${TMPDIR}/prefixes.ttl" \
    "${TMPDIR}/vochelp.ttl" \
    "${TMPDIR}/fibo-vP.nt" | \
  ${JENA_RIOT} \
    --syntax=turtle \
    --output=turtle > \
    "${tag_root}/fibo-vP.ttl"
  touch ${vocabulary_product_tag_root}/vocabulary.log
  #
  # JG>Dean I didn't find any hygiene*.sparql files anywhere
  #
#  log "Running tests"
#  ${FIND} ${vocabulary_script_dir}/testing -name 'hygiene*.sparql' -print
#  ${FIND} ${vocabulary_script_dir}/testing -name 'hygiene*.sparql' \
#    -exec ${JENA_ARQ} --data="${tag_root}/fibo-v.ttl" --query={} \;

  vocabularyConvertTurtleToAllFormats || return $?

  (cd "${tag_root}"; rm -f **.zip)

  #
  # gzip --best --stdout "${tag_root}/fibo-vD.ttl" > "${tag_root}/fibo-vD.ttl.gz"
  #
  (cd "${tag_root}" ; zip fibo-vD.ttl.zip fibo-vD.ttl)
  #
  # gzip --best --stdout "${tag_root}/fibo-vD.rdf" > "${tag_root}/fibo-vD.rdf.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vD.rdf.zip fibo-vD.rdf)
  #
  # gzip --best --stdout "${tag_root}/fibo-vD.jsonld" > "${tag_root}/fibo-vD.jsonld.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vD.jsonld.zip fibo-vD.jsonld)
  #
  # gzip --best --stdout "${tag_root}/fibo-vB.ttl" > "${tag_root}/fibo-vP.ttl.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vP.ttl.zip fibo-vP.ttl)
  #
  # gzip --best --stdout "${tag_root}/fibo-vB.rdf" > "${tag_root}/fibo-vP.rdf.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vP.rdf.zip fibo-vP.rdf)
  #
  # gzip --best --stdout "${tag_root}/fibo-vB.jsonld" > "${tag_root}/fibo-vP.jsonld.gz"
  #
  (cd "${tag_root}" ; zip  fibo-vP.jsonld.zip fibo-vP.jsonld)

  log "Finished publishing the Vocabulary Product"

  return 0
}

function vocabularyConvertTurtleToAllFormats() {

  pushd "${tag_root}" >/dev/null

  for ttlFile in **/*.ttl ; do
    for format in json-ld rdf-xml ; do
      ${SCRIPT_DIR}/utils/convertRdfFile.sh turtle "${ttlFile}" "${format}" || return $?
    done || return $?
  done || return $?

  popd >/dev/null

  return $?
}

#
# Called by publishProductVocabulary(), sets the names of all modules in the global variable modules and their
# root directories in the global variable module_directories
#
# 1) Determine which modules will be included. They are kept on a property
#    called <http://www.edmcouncil.org/skosify#module> in skosify.ttl
#
# JG>Apache jena3 is also installed on the Jenkins server itself, so maybe
#    no need to have this in the fibs-infra repo.
#
function vocabularyGetModules() {

  require vocabulary_script_dir || return $?
  require ontology_product_tag_root || return $?

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  log "Query the skosify.ttl file for the list of modules (TODO: Should come from rdf-toolkit.ttl)"

  ${JENA_ARQ} \
    --results=CSV \
    --data="${vocabulary_script_dir}/skosify.ttl" \
    --query="${vocabulary_script_dir}/get-module.sparql" | ${GREP} -v list > \
    "${TMPDIR}/module"

  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    error "Could not get modules"
    return 1
  fi

  cat "${TMPDIR}/module"

  export modules="$(< "${TMPDIR}/module")"

  export module_directories="$(for module in ${modules} ; do echo -n "${ontology_product_tag_root}/${module} " ; done)"

  log "Found the following modules:"
  echo ${modules}

  log "Using the following directories:"
  echo ${module_directories}

  rm -f "${TMPDIR}/module"

  return 0
}

#
# 2) Compute the prefixes we'll need.
#
function vocabularyGetPrefixes() {

  require vocabulary_script_dir || return $?
  require ontology_product_tag_root || return $?
  require modules || return $?
  require module_directories || return $?

  log "Get prefixes"

  cat "${vocabulary_script_dir}/basic-prefixes.ttl" > "${TMPDIR}/prefixes.ttl"

  pushd "${ontology_product_tag_root}" >/dev/null
  ${GREP} -R --include "*.ttl" --no-filename "@prefix fibo-" >> "${TMPDIR}/prefixes.ttl"
  popd >/dev/null

  #
  # Sort and filter out duplicates
  #
  sort --unique --output="${TMPDIR}/prefixes.ttl" "${TMPDIR}/prefixes.ttl"

  log "Found the following namespaces and prefixes:"
  cat "${TMPDIR}/prefixes.ttl"

  return 0
}

#
# 3) Gather up all the RDF files in those modules.  Include skosify.ttl, since that has the rules
#
# Generates TMPDIR/temp0.ttl
#
function vocabularyGetOntologies() {

  require vocabulary_script_dir || return $?
  require module_directories || return $?

  logStep "vocabularyGetOntologies"

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  log "Get Ontologies into merged file (temp0.ttl)"

  log "Files that go into dev:"

  while read -r fileName ; do
    log "- $(logFileName "${fileName}")"
  done < <(getDevOntologies)

  log "Files that go into prod:"

  while read -r fileName ; do
    log "$(logFileName "${fileName}")"
  done < <(getProdOntologies)

  #
  # Get ontologies for Dev
  #
  # shellcheck disable=SC2046
  #
  ${JENA_ARQ} \
    $(getDevOntologies | ${SED} "s/^/--data=/") \
    --data="${vocabulary_script_dir}/skosify.ttl" \
    --data="${vocabulary_script_dir}/datatypes.rdf" \
    --query="${vocabulary_script_dir}/skosecho.sparql" \
    --results=TTL > "${TMPDIR}/temp0.ttl"

  if [[ ${PIPESTATUS[0]} -ne 0 ]] ; then
    error "Could not get Dev ontologies"
    return 1
  fi

  #
  # Get ontologies for Prod
  #
  # shellcheck disable=SC2046
  #
  ${JENA_ARQ} \
    $(getProdOntologies | ${SED} "s/^/--data=/") \
    --data="${vocabulary_script_dir}/skosify.ttl" \
    --data="${vocabulary_script_dir}/datatypes.rdf" \
    --query="${vocabulary_script_dir}/skosecho.sparql" \
    --results=TTL > "${TMPDIR}/temp0B.ttl"

  if [[ ${PIPESTATUS[0]} -ne 0 ]] ; then
    error "Could not get Prod ontologies"
    return 1
  fi

  log "Generated $(logFileName "${TMPDIR}/temp0.ttl"):"

  head -n200 "${TMPDIR}/temp0.ttl"

  log "Generated $(logFileName "${TMPDIR}/temp0B.ttl"):"

  head -n200 "${TMPDIR}/temp0B.ttl"

  return 0
}

#
# Run SPIN
#
# JG>WHat does this do?
#
# Generates TMPDIR/temp1.ttl
#
function vocabularyRunSpin() {

  log "STARTING SPIN"

  rm -f "${TMPDIR}/temp1.ttl" >/dev/null 2>&1
  rm -f "${TMPDIR}/temp1B.ttl" >/dev/null 2>&1

  "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/temp0.ttl" "${TMPDIR}/temp1.ttl" || return $?
  "${SCRIPT_DIR}/utils/spinRunInferences.sh" "${TMPDIR}/temp0B.ttl" "${TMPDIR}/temp1B.ttl" || return $?

  logItem "Generated" "$(logFileName "${TMPDIR}/temp1.ttl"):"
  logItem "Generated" "$(logFileName "${TMPDIR}/temp1B.ttl"):"

  log "Printing first 50 lines of $(logFileName "${TMPDIR}/temp1.ttl")"
  head -n50 "${TMPDIR}/temp1.ttl"

  log "Printing first 50 lines of $(logFileName "${TMPDIR}/temp1B.ttl")"
  head -n50 "${TMPDIR}/temp1B.ttl"

  #The first three lines contain some WARN statements - removing it to complete the build.
  #JC > Need to check why this happens
  #log "Removing the first three lines from ${TMPDIR}/temp1.ttl"
  #${SED} -i.bak -e '1,3d' "${TMPDIR}/temp1.ttl"
  #log "Printing first 50 lines of ${TMPDIR}/temp1.ttl"
  #head -n50 "${TMPDIR}/temp1.ttl"

  #log "Removing the first three lines from ${TMPDIR}/temp1B.ttl"
  #${SED} -i.bak -e '1,3d' "${TMPDIR}/temp1B.ttl"
  #log "Printing first 50 lines of ${TMPDIR}/temp1B.ttl"
  #head -n50 "${TMPDIR}/temp1B.ttl"

  ### END Karthik changes

  return 0
}

#
# 4) Run the schemify rules.  This adds a ConceptScheme to the output.
#
function vocabularyRunSchemifyRules() {

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  log "Run the schemify rules"

  #
  # Dev
  #
  ${JENA_ARQ} \
    --data="${TMPDIR}/temp1.ttl" \
    --data="${vocabulary_script_dir}/schemify.ttl" \
    --query="${vocabulary_script_dir}/skosecho.sparql" \
    --results=TTL > "${TMPDIR}/temp2.ttl"

  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    error "Could not run the Dev schemify rules"
    return 1
  fi

  #
  # Prod
  #
  ${JENA_ARQ} \
    --data="${TMPDIR}/temp1B.ttl" \
    --data="${vocabulary_script_dir}/schemify.ttl" \
    --query="${vocabulary_script_dir}/skosecho.sparql" \
    --results=TTL > "${TMPDIR}/temp2B.ttl"

  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    error "Could not run the Prod schemify rules"
    return 1
  fi

  return 0
}
