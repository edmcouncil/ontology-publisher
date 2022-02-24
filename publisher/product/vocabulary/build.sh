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
  log "Merging all dev ontologies into one RDF file: $(logFileName ${tag_root}/dev.owl)"
  robot merge --input "${source_family_root}/${DEV_SPEC}" --output ${TMPDIR}/dev.owl

  #
  # Get ontologies for Prod
  #
  log "Merging all prod ontologies into one RDF file: : $(logFileName ${tag_root}/prod.owl)"
  robot merge --input "${source_family_root}/${PROD_SPEC}" --output ${TMPDIR}/prod.owl
  
  return 0
}

function vocabularyCreateFromOntologies() {

  require vocabulary_script_dir || return $?
  
  logStep "vocabularyCreateFromOntologies"
  log "Creating vocabularies form ontologies"
  

  log "Creating Dev vocabulary"
  ${JENA_ARQ} --data ${TMPDIR}/dev.owl --query ${SCRIPT_DIR}/product/vocabulary/classes.sparql --results=TTL > ${TMPDIR}/classes.ttl
  ${JENA_ARQ} --data ${TMPDIR}/dev.owl --query ${SCRIPT_DIR}/product/vocabulary/subclasses.sparql --results=TTL > ${TMPDIR}/subclasses.ttl
  ${JENA_ARQ} --data ${TMPDIR}/dev.owl --query ${SCRIPT_DIR}/product/vocabulary/properties.sparql --results=TTL > ${TMPDIR}/properties.ttl
  ${JENA_ARQ} --data ${TMPDIR}/dev.owl --query ${SCRIPT_DIR}/product/vocabulary/subproperties.sparql --results=TTL > ${TMPDIR}/subproperties.ttl
  

  ${JENA_ARQ} \
    --data ${SCRIPT_DIR}/product/vocabulary/scaffolding.ttl \
    --data ${TMPDIR}/classes.ttl \
    --data ${TMPDIR}/subclasses.ttl \
    --data ${TMPDIR}/properties.ttl \
    --data ${TMPDIR}/subproperties.ttl \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.ttl
	
  log "Creating Prod vocabulary"
  ${JENA_ARQ} --data ${TMPDIR}/prod.owl --query ${SCRIPT_DIR}/product/vocabulary/classes.sparql --results=TTL > ${TMPDIR}/classes.ttl
  ${JENA_ARQ} --data ${TMPDIR}/prod.owl --query ${SCRIPT_DIR}/product/vocabulary/subclasses.sparql --results=TTL > ${TMPDIR}/subclasses.ttl
  ${JENA_ARQ} --data ${TMPDIR}/prod.owl --query ${SCRIPT_DIR}/product/vocabulary/properties.sparql --results=TTL > ${TMPDIR}/properties.ttl
  ${JENA_ARQ} --data ${TMPDIR}/prod.owl --query ${SCRIPT_DIR}/product/vocabulary/subproperties.sparql --results=TTL > ${TMPDIR}/subproperties.ttl
  
  ${JENA_ARQ} \
    --data ${SCRIPT_DIR}/product/vocabulary/scaffolding.ttl \
    --data ${TMPDIR}/classes.ttl \
    --data ${TMPDIR}/subclasses.ttl \
    --data ${TMPDIR}/properties.ttl \
    --data ${TMPDIR}/subproperties.ttl \
    --query=/publisher/lib/echo.sparql \
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
	--query=/publisher/lib/echo.sparql \
	--results=RDF > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.rdf
	
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.ttl \
	--query=/publisher/lib/echo.sparql \
	--results=JSONLD > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vD.jsonld
	
  log "Saving Prod vocabulary"
	
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vP.ttl \
	--query=/publisher/lib/echo.sparql \
	--results=RDF > ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vP.rdf
	
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/${ONTPUB_FAMILY}-vP.ttl \
	--query=/publisher/lib/echo.sparql \
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

