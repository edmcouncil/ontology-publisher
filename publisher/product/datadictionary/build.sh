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
function publishProductDataDictionary() {

  setProduct ontology || return $?
  export ontology_product_tag_root="${tag_root:?}"

  setProduct datadictionary || return $?
  export datadictionary_product_tag_root="${tag_root:?}"
  export datadictionary_product_tag_root_url="${tag_root_url:?}"

  publishProductDataDictionaryContent || return $?

  return 0
}

#
# Produce all artifacts for the datadictionary product
#
function publishProductDataDictionaryContent() {

  logRule "Publishing the content files of the datadictionary product"

  require source_family_root || return $?
  require ontology_product_tag_root || return $?
  require datadictionary_product_tag_root || return $?

  echo "datadictionary_product_tag_root_url=${datadictionary_product_tag_root_url}"

  export datadictionary_script_dir="${SCRIPT_DIR:?}/product/datadictionary"

  if [ ! -d "${datadictionary_script_dir}" ] ; then
    error "Could not find ${datadictionary_script_dir}"
    return 1
  fi

  local datadictionaryBaseName="${datadictionary_product_tag_root}/datadictionary"

  logRule "Creating data dictionaries"


  export DEV_SPEC="${DEV_SPEC:-About${ONTPUB_FAMILY^^}Dev.rdf}"
  export PROD_SPEC="${PROD_SPEC:-About${ONTPUB_FAMILY^^}Prod.rdf}"
  
  logRule "Running OntoViewer Toolkit to generate CSV files containing data from ontologies for DEV from path ${source_family_root}"
  debug=false ${ONTOVIEWER_TOOLKIT_JAVA} --data "${source_family_root}/${DEV_SPEC}"\
    --output "${datadictionaryBaseName}-dev.csv" \
    --filter-pattern edmcouncil \
    --ontology-mapping "${source_family_root}/catalog-v001.xml" 

  logRule "Running OntoViewer Toolkit to generate CSV files containing data from ontologies for PROD from path ${source_family_root}"
  debug=false ${ONTOVIEWER_TOOLKIT_JAVA} --data "${source_family_root}/${PROD_SPEC}" \
    --output "${datadictionaryBaseName}-prod.csv" \
    --filter-pattern edmcouncil \
    --ontology-mapping "${source_family_root}/catalog-v001.xml" 

  logRule "Writing from csv files to xlsx files"

  touch "${datadictionary_product_tag_root}/datadictionary.log"
  
  ${PYTHON3} ${SCRIPT_DIR}/lib/csv-to-xlsx.py \
    "${datadictionaryBaseName}-prod.csv" \
    "${datadictionaryBaseName}-prod.xlsx" \
    "${datadictionary_script_dir}/csvconfig"

  ${PYTHON3} ${SCRIPT_DIR}/lib/csv-to-xlsx.py \
    "${datadictionaryBaseName}-dev.csv" \
    "${datadictionaryBaseName}-dev.xlsx" \
    "${datadictionary_script_dir}/csvconfig"
  
  return 0
}
