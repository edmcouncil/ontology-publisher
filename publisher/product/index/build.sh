#!/usr/bin/env bash
#
# Generate the index "product" from the source ontologies
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

#
# Publish the product called "index"
#
function publishProductIndex() {

  setProduct ontology
  ontology_product_tag_root="${tag_root}"

  setProduct index || return $?
  index_product_tag_root="${tag_root}"

  export index_script_dir="${SCRIPT_DIR}/product/index"

  if [ ! -d "${index_script_dir}" ] ; then
    error "Could not find ${index_script_dir}"
    return 1
  fi

  (
    cd "${index_product_tag_root}" || return $?

    cat > OntologyIndex.csv << __HERE__
Ontology,Maturity Level
__HERE__

   ${GREP} -r 'hasMaturityLevel' "${ontology_product_tag_root}" | \
        ${GREP} '\.rdf' | \
        ${SED} 's!"/>!!; s!^.*/!!; s/.rdf:.*resource=".*utl-av;/,/' |\
        ${SED} 's/,Release$/,Production/; s/,Provisional/,Development/; s/,Informative/,Development/' >> OntologyIndex.csv

   ${PYTHON3} ${SCRIPT_DIR}/lib/csv-to-xlsx.py OntologyIndex.csv OntologyIndex.xlsx "${index_script_dir}/csvconfig"
 )

 return $?
}
