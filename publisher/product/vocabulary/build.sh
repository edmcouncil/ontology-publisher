#
# Produce all artifacts for the vocabulary product
#
function publishProductVocabulary() {

  #
  # Set the memory for ARQ
  #
  export JVM_ARGS=${JVM_ARGS:--Xmx4G}

  require JENAROOT || return $?

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
  
  vocabularyGetOntologies || return $?
  vocabularyCreateFromOntologies || return $?
  saveVocabulariesInOtherFormats || return $?
  zipThemAll || return $?
  
  return 0
}

function vocabularyGetOntologies() {

  require vocabulary_script_dir || return $?
  
  logStep "vocabularyGetOntologies"

  log "Get ontologies for dev and prod"
  
  #
  # Get ontologies for Dev
  #
  logItem "Merging all dev" "$(logFileName ${tag_root}/dev.owl)"
  robot merge --input "${source_family_root}/${DEV_SPEC}" --output ${TMPDIR}/dev.owl

  #
  # Get ontologies for Prod
  #
  logItem "Merging all prod" "$(logFileName ${tag_root}/prod.owl)"
  robot merge --input "${source_family_root}/${PROD_SPEC}" --output ${TMPDIR}/prod.owl
  
  return 0
}

function replace_variables() {
  sed	-e "s&ONTPUB_FAMILY&${ONTPUB_FAMILY}&g" \
	-e "s&PRODUCT_ROOT_URL&${product_root_url}&g" \
	-e "s&HYGIENE_TEST_PARAMETER_VALUE&${HYGIENE_TEST_PARAMETER_VALUE}&g" \
	-e "s&ONTPUB_NAME&${ONTPUB_FAMILY^^}&g"
}

function vocabularyCreateFromOntologies() {

  require ONTPUB_FAMILY || return $?
  require product_root_url || return $?
  require HYGIENE_TEST_PARAMETER_VALUE || return ?
  require vocabulary_script_dir || return $?
  require vocabulary_product_tag_root || return $?
  
  logStep "vocabularyCreateFromOntologies"
  log "Creating vocabularies from ontologies"

  logItem "Creating scaffolding file" "$(logFileName ${tag_root}/scaffolding.ttl)"
  rm -f "${TMPDIR}/scaffolding.ttl" ; replace_variables < "${SCRIPT_DIR}/product/vocabulary/scaffolding.ttl" > "${TMPDIR}/scaffolding.ttl"

  log "Creating Dev vocabulary"
  export data_ttl=""
  for SPARQL in ${SCRIPT_DIR}/product/vocabulary/*.sparql ; do
   if [ -r "${SPARQL}" ] ; then
    ttl="${TMPDIR}/$(basename "${SPARQL}" | sed 's/.sparql/.ttl/g')" ; rm -f "${ttl}"
    logItem "$(logFileName $(basename ${SPARQL}))" "$(logFileName ${tag_root}/$(basename ${ttl}))"
    ${JENA_ARQ} --data ${TMPDIR}/dev.owl --query <(replace_variables < "${SPARQL}") --results=TTL > "${ttl}" && export data_ttl="${data_ttl} --data ${ttl}"
   fi
  done

  logItem "Creating dev file" "$(logFileName ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.ttl)"
  ${JENA_ARQ} \
    --data "${TMPDIR}/scaffolding.ttl" \
    ${data_ttl} \
    --query=<(echo 'CONSTRUCT {?s ?p ?o} WHERE {?s ?p ?o}') \
    --results=TTL > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.ttl

  log "Creating Prod vocabulary"
  export data_ttl=""
  for SPARQL in ${SCRIPT_DIR}/product/vocabulary/*.sparql ; do
   if [ -r "${SPARQL}" ] ; then
    ttl="${TMPDIR}/$(basename "${SPARQL}" | sed 's/.sparql/.ttl/g')" ; rm -f "${ttl}"
    logItem "$(logFileName $(basename ${SPARQL}))" "$(logFileName ${tag_root}/$(basename ${ttl}))"
    ${JENA_ARQ} --data ${TMPDIR}/prod.owl --query <(replace_variables < "${SPARQL}") --results=TTL > "${ttl}" && export data_ttl="${data_ttl} --data ${ttl}"
   fi
  done

  logItem "Creating prod file" "$(logFileName ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vP.ttl)"
  ${JENA_ARQ} \
    --data "${TMPDIR}/scaffolding.ttl" \
    ${data_ttl} \
    --query=<(echo 'CONSTRUCT {?s ?p ?o} WHERE {?s ?p ?o}') \
    --results=TTL > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vP.ttl

  touch ${vocabulary_product_tag_root}/vocabulary.log

  return 0
}

function saveVocabulariesInOtherFormats() {

  require vocabulary_script_dir || return $?
  
  logStep "saveVocabulariesInOtherFormats"
  
  log "Saving Dev vocabulary"
  
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.ttl \
	--query=<(echo 'CONSTRUCT {?s ?p ?o} WHERE {?s ?p ?o}') \
	--results=RDF > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.rdf
	
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.ttl \
	--query=<(echo 'CONSTRUCT {?s ?p ?o} WHERE {?s ?p ?o}') \
	--results=JSONLD > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.jsonld
	
  log "Saving Prod vocabulary"
	
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vP.ttl \
	--query=<(echo 'CONSTRUCT {?s ?p ?o} WHERE {?s ?p ?o}') \
	--results=RDF > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vP.rdf
	
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vP.ttl \
	--query=<(echo 'CONSTRUCT {?s ?p ?o} WHERE {?s ?p ?o}') \
	--results=JSONLD > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vP.jsonld
	
  return 0
}


function zipThemAll () {
  log "Zipping vocabularies"

  (cd "${tag_root}"; rm -f **.zip)

  #
  # gzip --best --stdout "${tag_root}/${ONTPUB_FAMILY}-vD.ttl" > "${tag_root}/${ONTPUB_FAMILY}-vD.ttl.gz"
  #
  (cd "${tag_root}" ; zip ${ONTPUB_FAMILY}-vD.ttl.zip ${ONTPUB_FAMILY}-vD.ttl)
  #
  # gzip --best --stdout "${tag_root}/${ONTPUB_FAMILY}-vD.rdf" > "${tag_root}/${ONTPUB_FAMILY}-vD.rdf.gz"
  #
  (cd "${tag_root}" ; zip  ${ONTPUB_FAMILY}-vD.rdf.zip ${ONTPUB_FAMILY}-vD.rdf)
  #
  # gzip --best --stdout "${tag_root}/${ONTPUB_FAMILY}-vD.jsonld" > "${tag_root}/${ONTPUB_FAMILY}-vD.jsonld.gz"
  #
  (cd "${tag_root}" ; zip  ${ONTPUB_FAMILY}-vD.jsonld.zip ${ONTPUB_FAMILY}-vD.jsonld)
  #
  # gzip --best --stdout "${tag_root}/${ONTPUB_FAMILY}-vP.ttl" > "${tag_root}/${ONTPUB_FAMILY}-vP.ttl.gz"
  #
  (cd "${tag_root}" ; zip  ${ONTPUB_FAMILY}-vP.ttl.zip ${ONTPUB_FAMILY}-vP.ttl)
  #
  # gzip --best --stdout "${tag_root}/${ONTPUB_FAMILY}-vP.rdf" > "${tag_root}/${ONTPUB_FAMILY}-vP.rdf.gz"
  #
  (cd "${tag_root}" ; zip  ${ONTPUB_FAMILY}-vP.rdf.zip ${ONTPUB_FAMILY}-vP.rdf)
  #
  # gzip --best --stdout "${tag_root}/${ONTPUB_FAMILY}-vP.jsonld" > "${tag_root}/${ONTPUB_FAMILY}-vP.jsonld.gz"
  #
  (cd "${tag_root}" ; zip  ${ONTPUB_FAMILY}-vP.jsonld.zip ${ONTPUB_FAMILY}-vP.jsonld)
}

