#!/usr/bin/env bash
#
# Build, Test and Publish all products of the ontology family.
#
# This script needs to be run inside the Docker container that is based on the ontology-publisher image.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1

if [ -n "$BASH_ENV" ]; then . "$BASH_ENV"; fi

if [ -f ${SCRIPT_DIR}/lib/_functions.sh ] ; then
  # shellcheck source=lib/_functions.sh
  source ${SCRIPT_DIR}/lib/_functions.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source lib/_functions.sh || exit $?
fi
if [ -f ${SCRIPT_DIR}/lib/_globals.sh ] ; then
  # shellcheck source=lib/_globals.sh
  source ${SCRIPT_DIR}/lib/_globals.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source lib/_globals.sh || exit $?
fi
if [ -f ${SCRIPT_DIR}/product/ontology/build.sh ] ; then
  # shellcheck source=product/ontology/build.sh
  source ${SCRIPT_DIR}/product/ontology/build.sh
else
  source product/ontology/build.sh # This line is only there to make the IntelliJ Bash plugin see product/ontology/build.sh
fi
if [ -f ${SCRIPT_DIR}/product/index/build.sh ] ; then
  # shellcheck source=product/index/build.sh
  source ${SCRIPT_DIR}/product/index/build.sh
else
  source product/index/build.sh # This line is only there to make the IntelliJ Bash plugin see product/index/build.sh
fi
if [ -f ${SCRIPT_DIR}/product/datadictionary/build.sh ] ; then
  # shellcheck source=product/datadictionary/build.sh
  source ${SCRIPT_DIR}/product/datadictionary/build.sh
else
  source product/datadictionary/build.sh # This line is only there to make the IntelliJ Bash plugin see product/datadictionary/build.sh
fi
if [ -f ${SCRIPT_DIR}/product/vocabulary/build.sh ] ; then
  # shellcheck source=product/vocabulary/build.sh
  source ${SCRIPT_DIR}/product/vocabulary/build.sh
else
  source product/vocabulary/build.sh # This line is only there to make the IntelliJ Bash plugin see product/vocabulary/build.sh
fi
#
# This function returns true if the given file name resides in the test/dev "domain" (a root directory)
#
# TODO: Make it always return true when running in non-dev mode
# TODO: Make the regex expression configurable
#
function ontologyIsInTestDomain() {

  return 0 # remove this line only when you're developing in a local docker image

  local rdfFile="$1"

  [[ "${rdfFile}" =~ ^.*/*etc/.*$ ]] && return 0

  if [[ "${rdfFile}" =~ ^.*/*CAE/.*$ ]] ; then
   logItem "Ontology file is in test domain" "${rdfFile}"
   return 0
  fi

# logItem "Ontology file is not in test domain" "${rdfFile}"

  return 1
}

#
# Clean up before publishing
#
function cleanupBeforePublishing() {

  require spec_root || return $?
  require tag_root || return $?

 
  # find all empty files in /tmp directory and delete them
  #
  find "${tag_root}" -type f -empty -delete

  return $?
}

#
# We need to put the output of this job in a directory next to all other branches and never delete any of the
# other formerly published branches.
#
function zipWholeTagDir() {

  require spec_root || return $?
  require tag_root || return $?

  local -r tarGzFile="${tag_root}.tar.gz"
  local -r tarGzContentsFile="${tag_root}.tar.gz.log"
#  local -r zipttlFile="${tag_root}.ttl.zip"
#  local -r ziprdfFile="${tag_root}.rdf.zip"
#  local -r zipjsonFile="${tag_root}.jsonld.zip"

  (
    cd ${spec_root} && ${TAR} -czf "${tarGzFile}" "${tag_root/${spec_root}/.}"
  )
  [[ $? -ne 0 ]] && return 1

  log "Created $(logFileName "${tarGzFile}"),"
  log "saving contents list in $(logFileName "${tarGzContentsFile}")"
  ls -al "${tarGzFile}" > "${tarGzContentsFile}" 2>&1 || return $?

  return 0
}

#
# Given that the onto-viewer needs to get the latest config files ontology-publisher should process those alongside with ontology files.
# https://github.com/edmcouncil/ontology-publisher/issues/100
#
function publishOntoViewerConfigFiles () {

  require source_family_root || return $?
  require family_product_branch_tag || return $?
  require tag_root || return $?
  require tag_root_url || return $?

  local config_path="etc/onto-viewer-web-app/config"

  rm -rf "${tag_root}/${config_path}" ; install -d "${tag_root}/${config_path}"
  if [ -d "${source_family_root}/${config_path}" ] ; then
    logRule "install onto-viewer config files into \"$(logFileName "${tag_root_url}/${config_path}/")\"" && \
    for CONFIG_FILE in $(find "${source_family_root}/${config_path}" -type f -not -name \.\* ) ; do
      logItem "config file" "$(logFileName "$(basename "${CONFIG_FILE}")")"
      install -p -m0644 "${CONFIG_FILE}" "${tag_root}/${config_path}/"
    done
  fi

  #
  # Set the appropriate values in "ontology_config.yaml"
  # https://github.com/edmcouncil/ontology-publisher/issues/115 + https://github.com/edmcouncil/ontology-publisher/issues/120
  #
  local ontologyConfigYamlFile="${tag_root}/${config_path}/ontology_config.yaml"
  logRule "setup onto-viewer config file \"$(logFileName "${tag_root_url}/${config_path}/ontology_config.yaml")\""
  install -d "$(dirname "${ontologyConfigYamlFile}")"
  test -f "${ontologyConfigYamlFile}" || touch "${ontologyConfigYamlFile}"
#  logItem "download_directory" "$(logFileName "ontologies")" && \
#	yq -i ".ontologies.download_directory = [\"ontologies\"]" "${ontologyConfigYamlFile}"
#  logItem "catalog_path" "$(logFileName "ontologies/${family_product_branch_tag}/catalog-v001.xml")" && \
#	yq -i ".ontologies.catalog_path = [\"ontologies/${family_product_branch_tag}/catalog-v001.xml\"]" "${ontologyConfigYamlFile}"
  logItem ".ontologies.source.zip" "$(logFileName "${tag_root_url}/dev.rdf.zip#${family_product_branch_tag}/catalog-v001.xml")" && \
	yq -i "del(.ontologies.source.[] | select(has(\"zip\")))" "${ontologyConfigYamlFile}" && \
	yq -i ".ontologies.source += {\"zip\":\"${tag_root_url}/dev.rdf.zip#${family_product_branch_tag}/catalog-v001.xml\"}" "${ontologyConfigYamlFile}"
}

#
# We should output hygiene test results in some computer readable format, like csv.
# This should include the consistency results if they are available.
# https://github.com/edmcouncil/ontology-publisher/issues/97
#
function publishHygieneFiles () {

  require spec_family_root || return $?
  require tag_root || return $?
  require tag_root_url || return $?

  ontology_product_tag_root="${tag_root:?}"
  hygiene_product_tag_root="${ontology_product_tag_root/ontology/hygiene}"

  hygiene_path="etc/hygiene"

  rm -rf "${ontology_product_tag_root}/${hygiene_path}"
  if [ -d "${hygiene_product_tag_root}" ] ; then
    install -d "${ontology_product_tag_root}/${hygiene_path}" && \
    logRule "install hygiene test results into \"$(logFileName "${tag_root_url}/${hygiene_path}/")\"" && \
    for HYGIENE_FILE in $(find "${hygiene_product_tag_root}" -type f) ; do
      logItem "hygiene test file" "$(logFileName "$(basename "${HYGIENE_FILE}")")"
      install -p -m0644 "${HYGIENE_FILE}" "${ontology_product_tag_root}/${hygiene_path}/"
    done
  fi
}

function zipOntologyFiles () {

  require family_product_branch_tag || return $?
  require tag_root || return $?

  logStep "zipOntologyFiles"

  local zipttlDevFile="${tag_root}/dev.ttl.zip"
  local ziprdfDevFile="${tag_root}/dev.rdf.zip"
  local zipjsonldDevFile="${tag_root}/dev.jsonld.zip"
  local zipttlProdFile="${tag_root}/prod.ttl.zip"
  local ziprdfProdFile="${tag_root}/prod.rdf.zip"
  local zipjsonldProdFile="${tag_root}/prod.jsonld.zip"
    
  (
    cd "${spec_root}"
    #
    # Make sure that everything is world readable before we zip it
    #
    chmod -R g+r,o+r .
    zip -r ${zipttlDevFile} "${family_product_branch_tag}" -x \*.rdf \*.zip  \*.jsonld \*About${ONTPUB_FAMILY^^}Prod.ttl
    zip -r ${ziprdfDevFile} "${family_product_branch_tag}" -x \*.ttl \*.zip \*.jsonld \*About${ONTPUB_FAMILY^^}Prod.rdf
    zip -r ${zipjsonldDevFile} "${family_product_branch_tag}" -x \*.ttl \*.zip \*.rdf \*About${ONTPUB_FAMILY^^}Prod.jsonld

    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".ttl" | ${SED} 's/:.*$//' | xargs zip -r ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*About*.ttl' -print | ${GREP} -v "About${ONTPUB_FAMILY^^}Dev.ttl" |  xargs zip ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipttlProdFile}
    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".rdf" |   ${SED} 's/:.*$//' | xargs zip -r ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*About*.rdf' -print | ${GREP} -v "About${ONTPUB_FAMILY^^}Dev.rdf" | xargs zip ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${ziprdfProdFile}
    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".jsonld" |   ${SED} 's/:.*$//' | xargs zip -r ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*About*.jsonld' -print | ${GREP} -v "About${ONTPUB_FAMILY^^}Dev.jsonld" | xargs zip ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipjsonldProdFile}

  )

  log "Step: zipOntologyFiles finished"

  return 0
}


#
# Stuff for building nquads files
#
function quadify () {
    # extract owl:Ontology
    export O="$(rdfpipe -o pretty-xml "${1}" 2>/dev/null | getOntologyIRI)"
    test -n "${O}" && rdfpipe -o nquads "${1}" | sed "s#<file://$(realpath "${1}")>#<${O}>#g"
  }
  

function main() {

  initRootProcess
  initOSBasedTools || return $?
  initWorkspaceVars || return $?
  initRepoBasedTools || return $?
  initGitVars || return $?
  initJiraVars || return $?

  if [[ "$1" == "init" ]] ; then
    return 0
  fi

  #
  # If we specified any parameters (other than "init") then
  # assume that these are the product names we need to run
  #
  if [[ $# -gt 0 ]] ; then
    products="$*"
  else
    #
    # Since we'e running the whole show from one call to this script,
    # ensure that publishing it all is the last step. Otherwise do not
    # forget to call this one last.
    #
    products="${products} publish"
  fi

  log "Products selected: ${products}"

  for product in ${products} ; do
    if [[ "${product}" != "publish" && ! "${product}" =~ ^--* ]] ; then
      logRule "Publish ${ONTPUB_FAMILY^^}-product \"${product}\""
    fi
    case ${product} in
      onto*)
        product="ontology"
        publishProductOntology || return $?
        ;;
      hygiene*)
        product="hygiene"
        runHygieneTests || return $?
        ;;
      voca*)
        product="vocabulary"
        publishProductVocabulary || return $?
        ;;
      datadict*)
        product="datadictionary"
        publishProductDataDictionary || return $?
        ;;
      publish)
        #
        # "publish" is not really a product but an action that should come after
        # all the products have been run
        #
        logRule "Final publish stage"
        cleanupBeforePublishing || return $?
        zipWholeTagDir || return $?
        publishOntoViewerConfigFiles || return $?
        publishHygieneFiles || return $?
        ;;
      --*)
        continue
        ;;
      *)
        error "Unknown product ${product}"
        return 1
        ;;
    esac
    #
    # Always switch off tracing in case some product-script forgot
    #
    set +x
    #
    # Make clear in the log that a given product is done
    #
    case ${product} in
      publish)
        ;;
      hygiene)
        log "Finished hygiene tests"
        ;;
      *)
        log "Finished publication of ${ONTPUB_FAMILY^^}-product \"${product}\""
        ;;
    esac
  done

  return 0
}

main $@
rc=$?
log "End of \"./publish $*\", rc=${rc}"
exit ${rc}
