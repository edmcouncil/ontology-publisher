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

  echo "glossary_product_tag_root_url=${glossary_product_tag_root_url}"
  
  publishProductGlossaryContent || return $?

  return 0
}

#
# Produce all artifacts for the glossary product
#
function publishProductGlossaryContent() {

	logRule "Publishing the content files of the glossary product"

	require ontology_product_tag_root || return $?
	require glossary_product_tag_root || return $?

	local numberOfProductionLevelOntologyFiles=0

	export glossary_script_dir="${SCRIPT_DIR:?}/product/glossary"

	if [ ! -d "${glossary_script_dir}" ] ; then
		error "Could not find ${glossary_script_dir}"
		return 1
	fi
  
	${PYTHON3} ${SCRIPT_DIR}/lib/dictionary_maker.py --output="${TMPDIR}/glossary-dev.ttl" --ontology="${ontology_product_tag_root}/AboutFIBODev.rdf" 
        
    
    if [ ${PIPESTATUS[0]} -ne 0 ] ; then
      error "Could not get Dev ontologies"
      return 1
    fi

  return 0
}
