#!/usr/bin/env bash
#
# Build, Test and Publish all products of the FIBO ontology family.
#
# This script needs to be run inside the Docker container that is based on the ontology-publisher image.
#
# TODO: Make this script fibo independent, should support any "ontology family"
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1

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
if [ -f ${SCRIPT_DIR}/product/widoco/build.sh ] ; then
  # shellcheck source=product/widoco/build.sh
  source ${SCRIPT_DIR}/product/widoco/build.sh
else
  source product/widoco/build.sh # This line is only there to make the IntelliJ Bash plugin see product/widoco/build.sh
fi
if [ -f ${SCRIPT_DIR}/product/glossary/build.sh ] ; then
  # shellcheck source=product/glossary/build.sh
  source ${SCRIPT_DIR}/product/glossary/build.sh
else
  source product/glossary/build.sh # This line is only there to make the IntelliJ Bash plugin see product/glossary/build.sh
fi
if [ -f ${SCRIPT_DIR}/product/vocabulary/build.sh ] ; then
  # shellcheck source=product/vocabulary/build.sh
  source ${SCRIPT_DIR}/product/vocabulary/build.sh
else
  source product/vocabulary/build.sh # This line is only there to make the IntelliJ Bash plugin see product/vocabulary/build.sh
fi
if [ -f ${SCRIPT_DIR}/product/datadictionary/build.sh ] ; then
  # shellcheck source=product/datadictionary/build.sh
  source ${SCRIPT_DIR}/product/datadictionary/build.sh
else
  source product/datadictionary/build.sh # This line is only there to make the IntelliJ Bash plugin see product/datadictionary/build.sh
fi
if [ -f ${SCRIPT_DIR}/product/reference/build.sh ] ; then
  # shellcheck source=product/reference/build.sh
  source ${SCRIPT_DIR}/product/reference/build.sh
else
  source product/reference/build.sh # This line is only there to make the IntelliJ Bash plugin see product/reference/build.sh
fi
if [ -f ${SCRIPT_DIR}/product/fibopedia/build.sh ] ; then
  # shellcheck source=product/fibopedia/build.sh
  source ${SCRIPT_DIR}/product/fibopedia/build.sh
else
  source product/fibopedia/build.sh # This line is only there to make the IntelliJ Bash plugin see product/fibopedia/build.sh
fi
if [ -f ${SCRIPT_DIR}/product/htmlpages/build.sh ] ; then
  # shellcheck source=product/htmlpages/build.sh
  source ${SCRIPT_DIR}/product/htmlpages/build.sh
else
  source product/htmlpages/build.sh # This line is only there to make the IntelliJ Bash plugin see product/htmlpages/build.sh
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

  #find "${tag_root}" -type f -name 'ont-policy.*' -delete
  #find "${tag_root}" -type f -name 'location-mapping.*' -delete
  #
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
# Copy the static files of the site
#
function copySiteFiles() {

  require spec_root || return $?

  (
      #    cd "/publisher/static-site" || return $?
      cd "/input/${ONTPUB_FAMILY}/etc/site" || return $?

    #Replace GIT BRANCH and TAG in the glossary index html
    #
    # DA>JG, I commented this out since this doesn't make sense it seems.
    #    There is no string "GIT_BRANCH" in index.html and even if there
    #    were I think it should always point to master/latest anyway (which it
    #    already does)
    #
    # JG>DA yes I understand but we better rethink this whole model, most files
    #    should reside in one of the versioned product directories, not in any
    #    of the /static directories. For the overall site pages, that span all
    #    versions we should have a special environment variable in the main
    #    Jenkinsfile (in the fibo repo) that holds the BRANCH/TAG value of the
    #    version of fibo-infra that should be used as the source of those
    #    files.
    #
    #log "Replacing GIT_BRANCH  $GIT_BRANCH"
    #${SED} -i "s/GIT_BRANCH/$GIT_BRANCH/g" "static/glossary/index.html"
    #
    #log "Replacing GIT_TAG_NAME  $GIT_TAG_NAME"
    #${SED} -i "s/GIT_TAG_NAME/$GIT_TAG_NAME/g" "static/glossary/index.html"

    ${CP} -r * "${spec_root}/"
  )

  if [[ -f ${INPUT}/${ONTPUB_FAMILY}/LICENSE ]] ; then
    ${CP} ${INPUT}/${ONTPUB_FAMILY}/LICENSE "${spec_root}"
  else
    warning "Could not find license: $(logFileName "${INPUT}/${ONTPUB_FAMILY}/LICENSE")"
  fi

  (
    cd "${spec_root}" && chmod -R g+r,o+r .
  )

  return 0
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
    zip -r ${zipttlDevFile} "${family_product_branch_tag}" -x \*.rdf \*.zip  \*.jsonld \*AboutFIBOProd.ttl
    zip -r ${ziprdfDevFile} "${family_product_branch_tag}" -x \*.ttl \*.zip \*.jsonld \*AboutFIBOProd.rdf
    zip -r ${zipjsonldDevFile} "${family_product_branch_tag}" -x \*.ttl \*.zip \*.rdf \*AboutFIBOProd.jsonld

    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".ttl" | ${SED} 's/:.*$//' | xargs zip -r ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*About*.ttl' -print | ${GREP} -v "AboutFIBODev.ttl" |  xargs zip ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipttlProdFile}
    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".rdf" |   ${SED} 's/:.*$//' | xargs zip -r ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*About*.rdf' -print | ${GREP} -v "AboutFIBODev.rdf" | xargs zip ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${ziprdfProdFile}
    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".jsonld" |   ${SED} 's/:.*$//' | xargs zip -r ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*About*.jsonld' -print | ${GREP} -v "AboutFIBODev.jsonld" | xargs zip ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipjsonldProdFile}

  )

  log "Step: zipOntologyFiles finished"

  return 0
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
# Stuff for building nquads files
#
function quadify () {

    sed 's/^<.*$/& { &/;$a}' "$1" | serdi -p $(cat /proc/sys/kernel/random/uuid) -o nquads - 
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

  for product in ${products} ; do
    if [[ "${product}" != "publish" && ! "${product}" =~ ^--* ]] ; then
      logRule "Publish ${ONTPUB_FAMILY}-product \"${product}\""
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
      wido*)
        product="widoco"
        publishProductWidoco || return $?
        ;;
      index)
	      publishProductIndex || return $?
	      ;;
      voca*)
        product="vocabulary"
        publishProductVocabulary || return $?
        ;;
      glos*)
        product="glossary"
        publishProductGlossary || return $?
        ;;
      data*)
        product="datadictionary"
        publishProductDataDictionary || return $?
        ;;
      fibopedia)
        publishProductFIBOpedia || return $?
        ;;
      htmlpages)
        publishProductHTMLPages || return $?
        ;;
      refe*)
        publishProductReference || return $?
        ;;
      publish)
        #
        # "publish" is not really a product but an action that should come after
        # all the products have been run
        #
        logRule "Final publish stage"
        cleanupBeforePublishing || return $?
        zipWholeTagDir || return $?
        copySiteFiles || return $?
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
        log "Finished publication of ${ONTPUB_FAMILY}-product \"${product}\""
        ;;
    esac
  done

  return 0
}

main $@
rc=$?
log "End of \"./publish $*\", rc=${rc}"
exit ${rc}
