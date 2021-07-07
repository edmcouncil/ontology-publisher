#
# Produce all artifacts for the vocabulary product
#
# The output is in .ttl form in a file called fibo-v.ttl
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
  # Get external ontologies
  #
  log "Merging all external ontologies into one RDF file: $(logFileName ${TMPDIR}/external.ttl)"
  "${JENA_ARQ}" $(find "${SCRIPT_DIR}/lib/imports/" -name "*.rdf" | sed "s/^/--data=/") \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > "${TMPDIR}/external.ttl"
    
  #
  # Get ontologies for Dev
  #
  log "Merging all dev ontologies into one RDF file: $(logFileName ${TMPDIR}/dev.ttl)"
  "${JENA_ARQ}" $(find "${source_family_root}" -name "*.rdf" | grep -v "/etc/" | sed "s/^/--data=/") \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > "${TMPDIR}/pre_dev.ttl"
  
  ${JENA_ARQ} \
    --data ${TMPDIR}/external.ttl \
	--data ${TMPDIR}/pre_dev.ttl \
	--query=/publisher/lib/echo.sparql \
	--results=TTL > ${TMPDIR}/dev.ttl

  #
  # Get ontologies for Prod
  #
  log "Merging all prod ontologies into one RDF file: : $(logFileName ${TMPDIR}/prod.ttl)"
  "${JENA_ARQ}" \
    $(grep -r 'utl-av[:;.]Release' "${source_family_root}" | sed 's/:.*$//;s/^/--data=/' | grep -F ".rdf") \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > "${TMPDIR}/pre_prod.ttl"
  
  ${JENA_ARQ} \
    --data ${TMPDIR}/external.ttl \
	--data ${TMPDIR}/pre_prod.ttl \
	--query=/publisher/lib/echo.sparql \
	--results=TTL > ${TMPDIR}/prod.ttl

  return 0
}

function vocabularyCreateFromOntologies() {

  require vocabulary_script_dir || return $?
  
  logStep "vocabularyCreateFromOntologies"
  log "Creating vocabularies form ontologies"
  

  log "Creating Dev vocabulary"
  ${JENA_ARQ} --data ${TMPDIR}/dev.ttl --query ${SCRIPT_DIR}/product/vocabulary/classes.sparql --results=TTL > ${TMPDIR}/classes.ttl
  ${JENA_ARQ} --data ${TMPDIR}/dev.ttl --query ${SCRIPT_DIR}/product/vocabulary/subclasses.sparql --results=TTL > ${TMPDIR}/subclasses.ttl
  ${JENA_ARQ} --data ${TMPDIR}/dev.ttl --query ${SCRIPT_DIR}/product/vocabulary/properties.sparql --results=TTL > ${TMPDIR}/properties.ttl
  ${JENA_ARQ} --data ${TMPDIR}/dev.ttl --query ${SCRIPT_DIR}/product/vocabulary/subproperties.sparql --results=TTL > ${TMPDIR}/subproperties.ttl
  

  ${JENA_ARQ} \
    --data ${SCRIPT_DIR}/product/vocabulary/scaffolding.ttl \
    --data ${TMPDIR}/classes.ttl \
    --data ${TMPDIR}/subclasses.ttl \
    --data ${TMPDIR}/properties.ttl \
    --data ${TMPDIR}/subproperties.ttl \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > ${vocabulary_product_tag_root}/fibo-vD.ttl
	
  log "Creating Prod vocabulary"
  ${JENA_ARQ} --data ${TMPDIR}/prod.ttl --query ${SCRIPT_DIR}/product/vocabulary/classes.sparql --results=TTL > ${TMPDIR}/classes.ttl
  ${JENA_ARQ} --data ${TMPDIR}/prod.ttl --query ${SCRIPT_DIR}/product/vocabulary/subclasses.sparql --results=TTL > ${TMPDIR}/subclasses.ttl
  ${JENA_ARQ} --data ${TMPDIR}/prod.ttl --query ${SCRIPT_DIR}/product/vocabulary/properties.sparql --results=TTL > ${TMPDIR}/properties.ttl
  ${JENA_ARQ} --data ${TMPDIR}/prod.ttl --query ${SCRIPT_DIR}/product/vocabulary/subproperties.sparql --results=TTL > ${TMPDIR}/subproperties.ttl
  
  ${JENA_ARQ} \
    --data ${SCRIPT_DIR}/product/vocabulary/scaffolding.ttl \
    --data ${TMPDIR}/classes.ttl \
    --data ${TMPDIR}/subclasses.ttl \
    --data ${TMPDIR}/properties.ttl \
    --data ${TMPDIR}/subproperties.ttl \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > ${vocabulary_product_tag_root}/fibo-vP.ttl  
	
  return 0
}

function saveVocabulariesInOtherFormats() {

  require vocabulary_script_dir || return $?
  
  logStep "saveVocabulariesInOtherFormats"
  
  log "Saving Dev vocabulary"
  
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/fibo-vD.ttl \
	--query=/publisher/lib/echo.sparql \
	--results=RDF > ${vocabulary_product_tag_root}/fibo-vD.rdf
	
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/fibo-vD.ttl \
	--query=/publisher/lib/echo.sparql \
	--results=JSONLD > ${vocabulary_product_tag_root}/fibo-vD.jsonld
	
  log "Saving Prod vocabulary"
	
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/fibo-vP.ttl \
	--query=/publisher/lib/echo.sparql \
	--results=RDF > ${vocabulary_product_tag_root}/fibo-vP.rdf
	
  ${JENA_ARQ} \
    --data ${vocabulary_product_tag_root}/fibo-vP.ttl \
	--query=/publisher/lib/echo.sparql \
	--results=JSONLD > ${vocabulary_product_tag_root}/fibo-vP.jsonld
	
  return 0
}


function zipThemAll () {
  log "Zipping vocabularies"

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
  # gzip --best --stdout "${tag_root}/fibo-vP.ttl" > "${tag_root}/fibo-vP.ttl.gz"
  #
  #(cd "${tag_root}" ; zip  fibo-vP.ttl.zip fibo-vP.ttl)
  #
  # gzip --best --stdout "${tag_root}/fibo-vP.rdf" > "${tag_root}/fibo-vP.rdf.gz"
  #
  #(cd "${tag_root}" ; zip  fibo-vP.rdf.zip fibo-vP.rdf)
  #
  # gzip --best --stdout "${tag_root}/fibo-vP.jsonld" > "${tag_root}/fibo-vP.jsonld.gz"
  #
  #(cd "${tag_root}" ; zip  fibo-vP.jsonld.zip fibo-vP.jsonld)
}

