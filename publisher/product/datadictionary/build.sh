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

  require HYGIENE_TEST_PARAMETER_VALUE || return ?
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

  local maturityLevel="$(yq '.ontologies.maturity_level_definition.[] | "--maturity-level " + .iri + "=" + .label' < \
	"${source_family_root}/etc/onto-viewer-web-app/config/ontology_config.yaml" 2>/dev/null | xargs echo -n)"

  local maturityLevelProperty="$(yq '.ontologies | "--maturity-level-property " + .maturity_level_property' < \
	"${source_family_root}/etc/onto-viewer-web-app/config/ontology_config.yaml" 2>/dev/null | xargs echo -n)"

  local extractDataColumn="${DATADICTIONARY_COLUMNS:+ --extract-data-column $(echo "${DATADICTIONARY_COLUMNS}" | sed 's/|/ --extract-data-column /g')}"

  local dev_suffix=${DEV_SPEC/.rdf/}
  local prod_suffix=${PROD_SPEC/.rdf/}

  logRule "Running OntoViewer Toolkit to generate CSV files containing data from ontologies - see logs \"$(logFileName datadictionary.DEV.log)\""
  logItem "$(basename "${DEV_SPEC}")" "$(logFileName "${tag_root_url}/$(basename "${datadictionaryBaseName}-${dev_suffix}.csv")")"
  debug=false ${ONTOVIEWER_TOOLKIT_JAVA} --goal extract-data ${maturityLevel} ${maturityLevelProperty} ${extractDataColumn} --data "${source_family_root}/${DEV_SPEC}" \
    --output "${datadictionaryBaseName}-${dev_suffix}.csv" \
    --filter-pattern "${HYGIENE_TEST_PARAMETER_VALUE}" \
    --ontology-mapping "${source_family_root}/catalog-v001.xml" > "${datadictionary_product_tag_root}/datadictionary.DEV.log" 2>&1

  logRule "Running OntoViewer Toolkit to generate CSV files containing data from ontologies - see logs \"$(logFileName datadictionary.PROD.log)\""
  logItem "$(basename "${PROD_SPEC}")" "$(logFileName "${tag_root_url}/$(basename "${datadictionaryBaseName}-${dev_suffix}.csv")")"
  debug=false ${ONTOVIEWER_TOOLKIT_JAVA} --goal extract-data ${maturityLevel} ${maturityLevelProperty} ${extractDataColumn} --data "${source_family_root}/${PROD_SPEC}" \
    --output "${datadictionaryBaseName}-${prod_suffix}.csv" \
    --filter-pattern "${HYGIENE_TEST_PARAMETER_VALUE}" \
    --ontology-mapping "${source_family_root}/catalog-v001.xml" > "${datadictionary_product_tag_root}/datadictionary.PROD.log" 2>&1

  logRule "Writing from csv files to xlsx files for prod"

  echo -e "==== $(basename "${datadictionaryBaseName}-${prod_suffix}.xlsx")" > "${datadictionary_product_tag_root}/datadictionary.log"
  
  ${PYTHON3} ${SCRIPT_DIR}/lib/csv-to-xlsx.py \
    "${datadictionaryBaseName}-${prod_suffix}.csv" \
    "${datadictionaryBaseName}-${prod_suffix}.xlsx" \
    "${datadictionary_script_dir}/csvconfig" 2>&1 | tee -a "${datadictionary_product_tag_root}/datadictionary.log"

  logRule "Writing from csv files to xlsx files for dev"

  echo -e "\n==== $(basename "${datadictionaryBaseName}-${dev_suffix}.xlsx")" >> "${datadictionary_product_tag_root}/datadictionary.log"
  ${PYTHON3} ${SCRIPT_DIR}/lib/csv-to-xlsx.py \
    "${datadictionaryBaseName}-${dev_suffix}.csv" \
    "${datadictionaryBaseName}-${dev_suffix}.xlsx" \
    "${datadictionary_script_dir}/csvconfig" 2>&1 | tee -a "${datadictionary_product_tag_root}/datadictionary.log"
  
  return 0
}
