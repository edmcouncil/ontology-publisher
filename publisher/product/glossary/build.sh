#!/usr/bin/env bash
#
# Generate the glossary "product" from the source ontologies
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

#
# Produce all artifacts for the glossary product
#
function publishProductGlossary() {

  setProduct ontology || return $?
  export ontology_product_tag_root="${tag_root:?}"

  setProduct glossary || return $?
  export glossary_product_tag_root="${tag_root:?}"
  export glossary_product_tag_root_url="${tag_root_url:?}"

  publishProductGlossaryContent || return $?

  return 0
}

#
# Produce all artifacts for the glossary product
#
function publishProductGlossaryContent() {

  logRule "Publishing the content files of the glossary product"

  require source_family_root || return $?
  require ontology_product_tag_root || return $?
  require glossary_product_tag_root || return $?

  echo "glossary_product_tag_root_url=${glossary_product_tag_root_url}"

  export glossary_script_dir="${SCRIPT_DIR:?}/product/glossary"

  if [ ! -d "${glossary_script_dir}" ] ; then
    error "Could not find ${glossary_script_dir}"
    return 1
  fi

  local glossaryBaseName="${glossary_product_tag_root}/glossary"

  logRule "Collecting DEV and PROD ontologies"

  pushd "${ontology_product_tag_root}" &>/dev/null
  
  # Get external ontologies
  #
  log "Merging all external ontologies into one RDF file: $(logFileName ${TMPDIR}/external.rdf)"
  "${JENA_ARQ}" $(find "${SCRIPT_DIR}/lib/imports/" -name "*.rdf" | sed "s/^/--data=/") \
    --query=/publisher/lib/echo.sparql  \
    --results=RDF > "${TMPDIR}/external.rdf"
    
  #
  # Get ontologies for Dev
  #
  log "Merging all dev ontologies into one RDF file: $(logFileName ${TMPDIR}/dev.rdf)"
  "${JENA_ARQ}" $(find "${source_family_root}" -name "*.rdf" | grep -v "/etc/" | sed "s/^/--data=/") \
    --query=/publisher/lib/echo.sparql \
    --results=RDF > "${TMPDIR}/pre_dev.rdf"
  
  ${JENA_ARQ} \
    --data ${TMPDIR}/external.rdf \
    --data ${TMPDIR}/pre_dev.rdf \
    --query=/publisher/lib/echo.sparql \
    --results=RDF > ${TMPDIR}/dev.rdf

  #
  # Get ontologies for Prod
  #
  log "Merging all prod ontologies into one RDF file: : $(logFileName ${TMPDIR}/prod.rdf)"
  "${JENA_ARQ}" \
    $(grep -r 'utl-av[:;.]Release' "${source_family_root}" | sed 's/:.*$//;s/^/--data=/' | grep -F ".rdf") \
    --query=/publisher/lib/echo.sparql \
    --results=RDF > "${TMPDIR}/pre_prod.rdf"
  
  ${JENA_ARQ} \
    --data ${TMPDIR}/external.rdf \
    --data ${TMPDIR}/pre_prod.rdf \
    --query=/publisher/lib/echo.sparql \
    --results=RDF > ${TMPDIR}/prod.rdf
  
  if [ ${PIPESTATUS[0]} -ne 0 ] ; then
    error "Could not collect ontologies"
    return 1
  fi
  
  popd &>/dev/null
  
  logRule "Creating data dictionaries"
  
  #
  # Set the memory for ARQ
  #
  JVM_ARGS="--add-opens java.base/java.lang=ALL-UNNAMED"
  JVM_ARGS="${JVM_ARGS} -Dxxx=arq"
  JVM_ARGS="${JVM_ARGS} -Xms2g"
  JVM_ARGS="${JVM_ARGS} -Xmx4g"
  JVM_ARGS="${JVM_ARGS} -Dfile.encoding=UTF-8"
  JVM_ARGS="${JVM_ARGS} -Djava.io.tmpdir=\"${TMPDIR}\""
  export JVM_ARGS
  logVar JVM_ARGS
	
  ${JENA_ARQ} --data ${TMPDIR}/dev.rdf --query ${SCRIPT_DIR}/product/glossary/data_dictionary.sparql --results=CSV > ${TMPDIR}/dev_proto_data_dictionary.csv
  ${JENA_ARQ} --data ${TMPDIR}/prod.rdf --query ${SCRIPT_DIR}/product/glossary/data_dictionary.sparql --results=CSV > ${TMPDIR}/prod_proto_data_dictionary.csv
        
  logRule "Extending data dictionaries with generated definitions"
		
  ${PYTHON3} ${SCRIPT_DIR}/lib/dictionary_maker_no_sparql.py --input ${TMPDIR}/dev_proto_data_dictionary.csv --output "${glossaryBaseName}-dev.csv"
  ${PYTHON3} ${SCRIPT_DIR}/lib/dictionary_maker_no_sparql.py --input ${TMPDIR}/prod_proto_data_dictionary.csv --output "${glossaryBaseName}-prod.csv"
  
  logRule "Writing from csv files to xlsx files"

  touch "${glossary_product_tag_root}/glossary.log"
  
  ${PYTHON3} ${SCRIPT_DIR}/lib/csv-to-xlsx.py \
    "${glossaryBaseName}-prod.csv" \
    "${glossaryBaseName}-prod.xlsx" \
    "${glossary_script_dir}/csvconfig"

  ${PYTHON3} ${SCRIPT_DIR}/lib/csv-to-xlsx.py \
    "${glossaryBaseName}-dev.csv" \
    "${glossaryBaseName}-dev.xlsx" \
    "${glossary_script_dir}/csvconfig"
  
  return 0
}
