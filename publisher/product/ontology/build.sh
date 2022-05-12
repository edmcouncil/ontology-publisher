#!/usr/bin/env bash
#
# Generate the ontology "product" from the source ontologies
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

export SCRIPT_DIR="${SCRIPT_DIR}" # Yet another hack to silence IntelliJ
export speedy="${speedy:-0}"
export speedy=0

if [[ -f ${SCRIPT_DIR}/product/ontology/build-cats.sh ]] ; then
  # shellcheck source=build-cats.sh
  source ${SCRIPT_DIR}/product/ontology/build-cats.sh
else
  source build-cats.sh # This line is only there to make the IntelliJ Bash plugin see build-cats.sh
fi
if [[ -f ${SCRIPT_DIR}/product/ontology/build-about.sh ]] ; then
  # shellcheck source=build-about.sh
  source ${SCRIPT_DIR}/product/ontology/build-about.sh
else
  source build-about.sh # This line is only there to make the IntelliJ Bash plugin see build-about.sh
fi
if [[ -f ${SCRIPT_DIR}/product/ontology/build-theallfile.sh ]] ; then
  # shellcheck source=build-theallfile.sh
  source ${SCRIPT_DIR}/product/ontology/build-theallfile.sh
else
  source build-theallfile.sh # This line is only there to make the IntelliJ Bash plugin see build-theallfile.sh
fi

#
# Produce all artifacts for the ontology product
#
function publishProductOntology() {
  require spec_family_root || return $?
  require tag_root || return $?

  setProduct ontology || return $?

  ontology_product_tag_root="${tag_root:?}"

  
  ontologyCopyRdfToTarget || return $?
  ontologySearchAndReplaceStuff || return $?
  ontologyBuildCatalogs  || return $?
  ontologyBuildIndex  || return $?
  ontologyCreateAboutFiles || return $?
  ontologyConvertRdfToAllFormats || return $?

  createQuickVersions || return $?
  ontologyZipFiles > "${tag_root}/ontology-zips.log" || return $?

  if ((speedy)) ; then
    log "speedy=true -> Not doing quads because they are slow"
  else
    buildquads || return $?
  fi

  return 0
}

#
# Every hygiene test file has a '# banner <banner>' message, fetch that with this function
#
function getBannerFromSparqlTestFile() {

  local -r hygieneTestSparqlFile="$1"

  grep "banner" "${hygieneTestSparqlFile}" | cut -d\  -f 3-
}

function getHygieneTestFiles() {

  find "${TMPDIR}/hygiene/" -name 'testHygiene*.sparql'
}


function runHygieneTests() {

  local banner

  setProduct ontology || return $?

  ontology_product_tag_root="${tag_root:?}"
  hygiene_product_tag_root="${ontology_product_tag_root/ontology/hygiene}"
  install -d "${hygiene_product_tag_root}"

  #
  # Paramterize hygiene tests
  #  
  mkdir -p "${TMPDIR}/hygiene/"
  ${PYTHON3} ${SCRIPT_DIR}/lib/hygiene_tests_parametizer.py \
  --input_folder "${source_family_root}/etc/testing/hygiene_parameterized/" \
  --pattern "${HYGIENE_TEST_PARAMETER}" \
  --value "${HYGIENE_TEST_PARAMETER_VALUE}" \
  --output_folder "${TMPDIR}/hygiene/"

  #
  # Run consistency-check for DEV and PROD ontologies
  #

  rm -f "${hygiene_product_tag_root}/consistency-check.log" &>/dev/null

  test -n "${HYGIENE_WARN_INCONSISTENCY_SPEC_FILE_NAME}" && logRule "run consistency check at level: warning" && \
  for SPEC in ${HYGIENE_WARN_INCONSISTENCY_SPEC_FILE_NAME} ; do
   if [ -s "${source_family_root}/${SPEC}" ] && [ ! -d "${source_family_root}/${SPEC}" ] ; then
    rm -f ${TMPDIR}/console.txt
    logItem "${SPEC}" "$(getOntologyIRI < "${source_family_root}/${SPEC}")"
    if ${ONTOVIEWER_TOOLKIT_JAVA} --data "${source_family_root}/${SPEC}" \
        --output ${TMPDIR}/console.txt $(test -s "${source_family_root}/catalog-v001.xml" && echo "--ontology-mapping ${source_family_root}/catalog-v001.xml") \
        --goal consistency-check &> "${hygiene_product_tag_root}/consistency-check.log" ; then
      if head -n 1 "${TMPDIR}/console.txt" | grep '^true$' &>/dev/null ; then
        echo -e "\t\x1b\x5b\x33\x32\x6d$(echo "Ontology \"${SPEC}\" is consistent."   | tee -a "${hygiene_product_tag_root}/consistency-check.log")\x1b\x5b\x30\x6d"
      else
        echo -e "\t\x1b\x5b\x33\x31\x6d$(echo "Ontology \"${SPEC}\" is inconsistent." | tee -a "${hygiene_product_tag_root}/consistency-check.log")\x1b\x5b\x30\x6d"
      fi
    else
      echo -e "\t\x1b\x5b\x33\x31\x6dERROR\x1b\x5b\x30\x6d: running consistency-check - see 'consistency-check.log'"
      return 1
    fi
   fi
  done

  test -n "${HYGIENE_ERROR_INCONSISTENCY_SPEC_FILE_NAME}" && logRule "run consistency check at level: error" && \
  for SPEC in ${HYGIENE_ERROR_INCONSISTENCY_SPEC_FILE_NAME} ; do
   if [ -s "${source_family_root}/${SPEC}" ] && [ ! -d "${source_family_root}/${SPEC}" ] ; then
    rm -f ${TMPDIR}/console.txt
    logItem "${SPEC}" "$(getOntologyIRI < "${source_family_root}/${SPEC}")"
    if ${ONTOVIEWER_TOOLKIT_JAVA} --data "${source_family_root}/${SPEC}" \
        --output ${TMPDIR}/console.txt $(test -s "${source_family_root}/catalog-v001.xml" && echo "--ontology-mapping ${source_family_root}/catalog-v001.xml") \
        --goal consistency-check &>> "${hygiene_product_tag_root}/consistency-check.log" ; then
      if head -n 1 "${TMPDIR}/console.txt" | grep '^true$' &>/dev/null ; then
        echo -e "\t\x1b\x5b\x33\x32\x6d$(echo "Ontology \"${SPEC}\" is consistent."   | tee -a "${hygiene_product_tag_root}/consistency-check.log")\x1b\x5b\x30\x6d"
      else
        echo -e "\t\x1b\x5b\x33\x31\x6d$(echo "Ontology \"${SPEC}\" is inconsistent." | tee -a "${hygiene_product_tag_root}/consistency-check.log")\x1b\x5b\x30\x6d"
      fi
    else
      echo -e "\t\x1b\x5b\x33\x31\x6dERROR\x1b\x5b\x30\x6d: running consistency-check - see 'consistency-check.log'"
      return 1
    fi
   fi
  done

  rm -f ${TMPDIR}/console.txt &>/dev/null

  test -n "${HYGIENE_WARN_INCONSISTENCY_SPEC_FILE_NAME}${HYGIENE_ERROR_INCONSISTENCY_SPEC_FILE_NAME}" && logRule "consistency-check: end"

  #
  # Get ontologies for Dev
  #
  log "Merging all dev ontologies into one RDF file"
  ${PYTHON3} ${SCRIPT_DIR}/lib/ontology_collector.py \
     --root "${source_family_root}" \
     --input_ontology "${source_family_root}/${DEV_SPEC}" \
     --ontology-mapping "${source_family_root}/catalog-v001.xml" \
     --output_ontology "${TMPDIR}/DEV.ttl"

  success=$?
  if [ "${success}" != 0 ] ; then log "Merging dev ontologies encountered problem(s), so hygiene test results may be incomplete." ; fi
  
  #
  # Get ontologies for Prod
  #
  log "Merging all prod ontologies into one RDF file"
  ${PYTHON3} ${SCRIPT_DIR}/lib/ontology_collector.py \
     --root "${source_family_root}" \
     --input_ontology "${source_family_root}/${PROD_SPEC}" \
     --ontology-mapping "${source_family_root}/catalog-v001.xml" \
     --output_ontology "${TMPDIR}/PROD.ttl"

  success=$?
  if [ "${success}" != 0 ] ; then log "Merging prod ontologies encountered problem(s), so hygiene test results may be incomplete." ; fi
    
  logRule "Will run the following tests:"

  while read -r hygieneTestSparqlFile ; do
    banner=$(getBannerFromSparqlTestFile "${hygieneTestSparqlFile}")
    logItem "$(basename "${hygieneTestSparqlFile}")" "${banner}"
  done < <(getHygieneTestFiles)

  logRule "Errors in DEV:"

  DEVerrorscount=0
  DEVwarningscount=0
  while read -r hygieneTestSparqlFile ; do
    banner=$(getBannerFromSparqlTestFile "${hygieneTestSparqlFile}")
    logItem "Running test" "${banner}"
    ${JENA_ARQ} \
      --data=${TMPDIR}/DEV.ttl \
      --results=tsv \
      --query="${hygieneTestSparqlFile}" | tail -n +2 | dos2unix | \
      sed 's/^\(\W*\)PRODERROR:/\1WARN:/g' | \
      tee "${TMPDIR}"/console.txt | \
      sed -e 's#^"\(ERROR:[^\"]*\)"#\t\x1b\x5b\x33\x31\x6d\1\x1b\x5b\x30\x6d#g' \
          -e 's#^"\(WARN:[^\"]*\)"#\t\x1b\x5b\x33\x33\x6d\1\x1b\x5b\x30\x6d#g' \
          -e 's#^"\(INFO:[^\"]*\)"#\t\x1b\x5b\x33\x32\x6d\1\x1b\x5b\x30\x6d#g'
      errorscount=$(grep '^"ERROR:' "${TMPDIR}"/console.txt | wc -l) ; DEVerrorscount=$((${DEVerrorscount} + ${errorscount}))
      warningscount=$(grep '^"WARN:' "${TMPDIR}"/console.txt | wc -l) ; DEVwarningscount=$((${DEVwarningscount} + ${warningscount}))
      test   ${errorscount} -gt 0 && echo -e "   \x1b\x5b\x33\x32\x6derrors count per test\x1b\x5b\x30\x6d  :\t${errorscount}"
      test ${warningscount} -gt 0 && echo -e "   \x1b\x5b\x33\x32\x6dwarnings count per test\x1b\x5b\x30\x6d:\t${warningscount}"
  done < <(getHygieneTestFiles)

  test ${DEVwarningscount} -gt 0 && echo -e " \x1b\x5b\x33\x32\x6dDEV all warnings count\x1b\x5b\x30\x6d:\t${DEVwarningscount}"
  test   ${DEVerrorscount} -gt 0 && echo -e " \x1b\x5b\x33\x32\x6dDEV all errors count\x1b\x5b\x30\x6d  :\t${DEVerrorscount}"

  logRule "Errors in PROD:"

  PRODerrorscount=0
  PRODwarningscount=0
  while read -r hygieneTestSparqlFile ; do
    banner=$(getBannerFromSparqlTestFile "${hygieneTestSparqlFile}")
    logItem "Running test" "${banner}"
    ${JENA_ARQ} \
      --data=${TMPDIR}/PROD.ttl \
      --results=tsv \
      --query="${hygieneTestSparqlFile}" | tail -n +2 | dos2unix | \
      sed 's/^\(\W*\)PRODERROR:/\1ERROR:/g' | \
      tee "${TMPDIR}"/console.txt | \
      sed -e 's#^"\(ERROR:[^\"]*\)"#\t\x1b\x5b\x33\x31\x6d\1\x1b\x5b\x30\x6d#g' \
          -e 's#^"\(WARN:[^\"]*\)"#\t\x1b\x5b\x33\x33\x6d\1\x1b\x5b\x30\x6d#g' \
          -e 's#^"\(INFO:[^\"]*\)"#\t\x1b\x5b\x33\x32\x6d\1\x1b\x5b\x30\x6d#g'
      errorscount=$(grep '^"ERROR:' "${TMPDIR}"/console.txt | wc -l) ; PRODerrorscount=$((${PRODerrorscount} + ${errorscount}))
      warningscount=$(grep '^"WARN:' "${TMPDIR}"/console.txt | wc -l) ; PRODwarningscount=$((${PRODwarningscount} + ${warningscount}))
      test   ${errorscount} -gt 0 && echo -e "   \x1b\x5b\x33\x32\x6derrors count per test\x1b\x5b\x30\x6d  :\t${errorscount}"
      test ${warningscount} -gt 0 && echo -e "   \x1b\x5b\x33\x32\x6dwarnings count per test\x1b\x5b\x30\x6d:\t${warningscount}"
  done < <(getHygieneTestFiles)

  test ${PRODwarningscount} -gt 0 && echo -e " \x1b\x5b\x33\x32\x6dPROD all warnings count\x1b\x5b\x30\x6d:\t${PRODwarningscount}"
  test   ${PRODerrorscount} -gt 0 && echo -e " \x1b\x5b\x33\x32\x6dPROD all errors count\x1b\x5b\x30\x6d  :\t${PRODerrorscount}"

  allerrorscount=$((${DEVerrorscount} + ${PRODerrorscount}))
  test ${allerrorscount} -gt 0 && logItem "$(echo -e '\n\x1b\x5b\x33\x32\x6dall errors count\x1b\x5b\x30\x6d  ')" ${allerrorscount} && return 1

  mv -f "${TMPDIR}"/console.txt "${hygiene_product_tag_root}"/hygiene-test.log

  logRule "Passed all the hygiene tests"

  return 0
}

#
# Copy all publishable files from the ontology repo to the appropriate target directory (${tag_root})
# where they will be converted to publishable artifacts
#
function ontologyCopyRdfToTarget() {

  require source_family_root || return $?
  require tag_root || return $?

  local module

  logStep "ontologyCopyRdfToTarget"

  log "Copying all artifacts that we publish straight from git into $(logFileName "${tag_root}")"

  (
    rm -rf "${tag_root}"
    mkdir -p "${tag_root}"
    cd "${source_family_root}" || return $?
    while read -r file ; do
      if ontologyIsInTestDomain "${file}" ; then
        "${CP}" "${file}" --parents "${tag_root}/"
      fi
    done < <(
      find . \
        -name '*.rdf'   -o \
        -name '*.ttl'   -o \
        -name '*.md'    -o \
        -name '*.jpg'   -o \
        -name '*.png'   -o \
        -name '*.gif'   -o \
        -name '*.docx'  -o \
        -name '*.pdf'   -o \
        -name '*.sq'    -o \
        -name '*.sparql'
    )
  )

  # Clean up a few things that are too embarrassing to publish
  #
  rm -vrf ${tag_root}/etc/cm >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/data >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/image >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/infra >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/odm >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/operational >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/source >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/spec >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/testing >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/uml >/dev/null 2>&1
  rm -vrf ${tag_root}/**/archive >/dev/null 2>&1
  rm -vrf ${tag_root}/**/Bak >/dev/null 2>&1


  return 0
}

function ontologySearchAndReplaceStuff() {

  logStep "ontologySearchAndReplaceStuff"

  require ONTPUB_SPEC_HOST || return $?
  require spec_family_root_url || return $?
  require product_root_url || return $?
  require GIT_BRANCH || return $?
  require GIT_TAG_NAME || return $?

  local -r sedfile=$(mktemp ${TMPDIR}/sed.XXXXXX)

  cat > "${sedfile}" << __HERE__
  #
  # First replace all http:// urls to https:// if that's not already done
  #

  s@http://${ONTPUB_SPEC_HOST}@${spec_root_url}@g
  
  #
  # Replace all IRIs in the form:
  #
  # - https://spec.edmcouncil.org/fibo/XXX/ with
  # - https://spec.edmcouncil.org/fibo/ontology/XXX/
  #
  # This replacement should not really be necessary since we've changed all those non-/ontology/ IRIs
  # in the git sources with their /ontology/-counterparts but the publisher should be able to support
  # older versions of the sources as well so we leave this in here.
  #
  
  s@${spec_family_root_url}/\([A-Z]*\)/@${product_root_url}/\1/@g
  
  #
  # Dealing with special case /ext/.
  #
  
  s@${spec_family_root_url}/ext/@${product_root_url}/ext/@g
  
  #
  # Then replace some odd ones with a version number in it like:
  #
  # - https://spec.edmcouncil.org/fibo/ontology/20150201/
  #
  # with
  #
  # - https://spec.edmcouncil.org/fibo/ontology/
  #
  # or:
  #
  # - https://spec.edmcouncil.org/fibo/ontology/BE/20150201/
  #
  # with
  #
  # - https://spec.edmcouncil.org/fibo/ontology/BE/
  #
  
  s@${product_root_url}/\([A-Z]*/\)\?[0-9]*/@${product_root_url}/\1@g
  
  #
  # We only want the following types of IRIs to be versioned: owl:imports and owl:versionIRI.
  #
  # - <owl:imports rdf:resource="https://spec.edmcouncil.org/fibo/ontology/FND/InformationExt/InfoCore/"/> becomes:
  # - <owl:imports rdf:resource="https://spec.edmcouncil.org/fibo/ontology/master/latest/FND/InformationExt/InfoCore/"/>
  #
  
  s@\(owl:imports rdf:resource="${product_root_url}/\)@\1${branch_tag}/@g
  
  #
  # And then the same for the owl:versionIRI.
  #
  
  s@\(owl:versionIRI rdf:resource="${product_root_url}/\)@\1${branch_tag}/@g
  
  #
  # Just to be sure that we don't see any 'ontology/ontology' IRIs:
  #
  
  s@/ontology/ontology/@/ontology/@g
  
  #
__HERE__

#   cat "${sedfile}"

  (
    ${FIND} ${tag_root}/ -type f \( -name '*.rdf' -o -name '*.ttl' -o -name '*.md' \) -exec ${SED} -i -f ${sedfile} {} \;
  )

  rm -f "${sedfile}"

  #
  # We want to add in a rdfs:isDefinedBy link from every class back to the ontology.
  #
  if ((speedy)) ; then
	  log "speedy=true -> Leaving out isDefinedBy because it is slow"
	else
	  #${tag_root}/ -type f  -name '*.rdf' -not -name '*About*'  -print | \
	  #xargs -P $(nproc) -I fileName
	  ${FIND} ${tag_root}/ -type f  -name '*.rdf' -not -name '*About*'  -print | while read file ; do
	    ontologyAddIsDefinedBy "${file}"
    done
  fi

  return 0
}

#
# Add isDefinedBy triples to a single file
#
function ontologyAddIsDefinedBy () {

  local file="$1"

  logItem "add isDefinedBy to" "$(logFileName "${file}")"


  ${PYTHON3} ${SCRIPT_DIR}/lib/addIsDefinedBy.py --file="${file}"


  ${SCRIPT_DIR}/utils/convertRdfFile.sh turtle "${file/.rdf/.ttl}" "rdf-xml"

  return $?
}

#
# For the .ttl files, find the ontology, and compute the version IRI from it.
# Put it in a cookie where TopBraid will find it.
#
function ontologyFixTopBraidBaseURICookie() {

  local ontologyFile="$1"
  local queryFile="$2"
  local baseURI
  local uri

  log "Annotating $(logFileName "${ontologyFile}")"

  log "CSV output of query is:"

  "${JENA_ARQ}" \
      --query="${queryFile}" \
      --data="${ontologyFile}" \
      --results=csv

  baseURI=$( \
    "${JENA_ARQ}" \
      --query="${queryFile}" \
      --data="${ontologyFile}" \
      --results=csv | \
      ${GREP} edmcouncil | \
      ${SED} "s@\(${product_root_url}/\)@\1${branch_tag}/@" | \
      ${SED} "s@${branch_tag}/${branch_tag}/@${branch_tag}/@" \
  )

  uri="# baseURI: ${baseURI}"

  ${SED} -i "1s;^;${uri}\n;" "${ontologyFile}"
}

#
# The "index" is a list of all the ontology files, in their
# directory structure.  This is an attempt to automatically produce
# this.
#
function ontologyBuildIndex () {

  require tag_root || return $?
  require tag_root_url || return $?
  require GIT_TAG_NAME || return $?

  (
  	cd ${tag_root:?} || return $?
  	while read directory ; do
  	  #log "Directory is ${directory}"
  	  (
  	    cd "${directory}" || return $?
  	    ${TREE} -P '*.rdf|*.html' -T "Directory Tree" -H "${tag_root_url:?}/${directory/.\//}" --noreport --charset=UTF8 -N | \
          ${SED} \
            -e 's/.VERSION { font-size: small;/.VERSION { display: none; font-size: small;/g' \
            -e 's/BODY {.*}/BODY { font-family : "Courier New"; font-size: 12pt ; line-height: 0.90}/g' \
            -e 's/ariel/"Courier New"/g' \
            -e 's/<hr>//g' \
            -e "s@>Directory Tree<@>Ontology file directory ${directory/.\//}<@g" \
            -e 's@h1>\n<p>@h1><p>This is the directory structure of ontology; you can download individual files this way.</a>.<p/>@' \
            -e "s@<a href=\".*>${spec_root_url}/.*</a>@@" > tree.html
  	  )
  	done < <(${FIND} . -type d)
	)

	return $?
}

function ontologyConvertRdfToAllFormats() {

  require tag_root || return $?

  logStep "ontologyConvertRdfToAllFormats"

  pushd "${tag_root:?}" >/dev/null || return $?

  local -r maxParallelJobs=8
  local numberOfParallelJobs=0
  local formats

  if ((speedy)) ; then
    formats="turtle"
  else
    formats="turtle json-ld"
  fi

  log "Running ${maxParallelJobs} converter jobs in parallel:"

  for rdfFile in **/*.rdf ; do
    ontologyIsInTestDomain "${rdfFile}" || continue
    for format in ${formats} ; do
      if ((maxParallelJobs == 1)) ; then
        ${SCRIPT_DIR}/utils/convertRdfFile.sh rdf-xml "${rdfFile}" "${format}" || return $?
      else
        ${SCRIPT_DIR}/utils/convertRdfFile.sh rdf-xml "${rdfFile}" "${format}" &
        ((numberOfParallelJobs++))
        if ((numberOfParallelJobs >= maxParallelJobs)) ; then
          wait
          numberOfParallelJobs=0
        fi
      fi
    done || return $?
  done || return $?
  rc=$?

#  ((maxParallelJobs > 1)) && wait

  popd >/dev/null || return $?

  log "End of ontologyConvertRdfToAllFormats"

  return $?
}

function ontologyZipFiles () {

  require family_product_branch_tag || return $?
  require tag_root || return $?

  logStep "ontologyZipFiles"

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

    #
    # [edmcouncil/ontology-publisher#25](https://github.com/edmcouncil/ontology-publisher/issues/25)
    # [INFRA-498](https://jira.edmcouncil.org/browse/INFRA-498)
    #
    # formatting the '@prefix ...' lines
    #
    find . -type f -name \*\.ttl -exec /bin/bash -c 'perl -pi -e "s/^\s*(\@prefix)\s+([^\s]+)\s+(\<[^\>]*\>)\s+(\.)\s*$/\1 \2 \3 \4\n/g" "{}"' \;


    ${FIND}  "${family_product_branch_tag}" -name '*.ttl' -print | ${GREP} -v etc |  ${GREP} -v "Load${ONTPUB_FAMILY^^}Prod.ttl" | grep -v About |  xargs zip ${zipttlDevFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipttlDevFile}

    ${FIND}  "${family_product_branch_tag}" -name '*.rdf' -print | ${GREP} -v etc | ${GREP} -v "Load${ONTPUB_FAMILY^^}Prod.rdf" |  grep -v About |xargs zip ${ziprdfDevFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${ziprdfDevFile}

    ${FIND}  "${family_product_branch_tag}" -name '*.jsonld' -print | ${GREP} -v etc | ${GREP} -v "Load${ONTPUB_FAMILY^^}Prod.jsonld" |  grep -v About |  xargs zip ${zipjsonldDevFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipjsonldDevFile}


    

    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".ttl" | ${SED} 's/:.*$//' | xargs zip -r ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*Load*.ttl' -print | ${GREP} -v "Load${ONTPUB_FAMILY^^}Dev.ttl" |  xargs zip ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipttlProdFile}
    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".rdf" |   ${SED} 's/:.*$//' | xargs zip -r ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*Load*.rdf' -print | ${GREP} -v "Load${ONTPUB_FAMILY^^}Dev.rdf" | xargs zip ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${ziprdfProdFile}
    ${GREP} -r 'https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/Release' "${family_product_branch_tag}" | ${GREP} -F ".jsonld" |   ${SED} 's/:.*$//' | xargs zip -r ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*Load*.jsonld' -print | ${GREP} -v "Load${ONTPUB_FAMILY^^}Dev.jsonld" | xargs zip ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipjsonldProdFile}

  )

  log "Step: ontologyZipFiles finished"

  return 0
}

function buildquads () {

  local ProdQuadsFile="${tag_root}/prod.${ONTPUB_FAMILY}.nq"
  local DevQuadsFile="${tag_root}/dev.${ONTPUB_FAMILY}.nq"

  local ProdFlatNT="${tag_root}/old_prod.${ONTPUB_FAMILY}-quickstart.nt"
  local DevFlatNT="${tag_root}/old_dev.${ONTPUB_FAMILY}-quickstart.nt"

  local ProdFlatTTL="${tag_root}/old_prod.${ONTPUB_FAMILY}-quickstart.ttl"
  local DevFlatTTL="${tag_root}/old_dev.${ONTPUB_FAMILY}-quickstart.ttl"

  local ProdTMPTTL="$(mktemp ${TMPDIR}/prod.temp.XXXXXX.ttl)"
  local DevTMPTTL="$(mktemp ${TMPDIR}/dev.temp.XXXXXX.ttl)"

  local CSVPrefixes="${tag_root}/prefixes.${ONTPUB_FAMILY}.csv"
  local TTLPrefixes="${tag_root}/prefixes.${ONTPUB_FAMILY}.ttl"
  local SPARQLPrefixes="${tag_root}/prefixes.${ONTPUB_FAMILY}.sq"


  local tmpflat="$(mktemp ${TMPDIR}/flatten.XXXXXX.sq)"
  cat >"${tmpflat}" << __HERE__
PREFIX owl: <http://www.w3.org/2002/07/owl#> 

CONSTRUCT {?s ?p ?o}
WHERE {GRAPH ?g {?s ?p ?o
FILTER NOT EXISTS {?s a owl:Ontology}
}
}
__HERE__

  local tmpflatecho="$(mktemp ${TMPDIR}/flattecho.XXXXXX.sq)"
  cat >"${tmpflatecho}" << __HERE__
PREFIX owl: <http://www.w3.org/2002/07/owl#> 

CONSTRUCT {?s ?p ?o}
WHERE {?s ?p ?o
FILTER NOT EXISTS {?s a owl:Ontology}
}
__HERE__


  local tmppx="$(mktemp ${TMPDIR}/px.XXXXXX.sq)"
  cat >"${tmppx}" << __HERE__
prefix sm: <http://www.omg.org/techprocess/ab/SpecificationMetadata/>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix xsd: <http://www.w3.org/2001/XMLSchema#>

SELECT ?line
WHERE {graph ?g {?o a owl:Ontology ;
sm:fileAbbreviation ?px
BIND (CONCAT ("prefix ", ?px, ": <", xsd:string(?o), ">") AS ?line)
}
}
__HERE__

  local tmpecho="$(mktemp ${TMPDIR}/echo.XXXXXX.sq)"
  cat >"${tmpecho}" << __HERE__
CONSTRUCT {?s ?p ?o}
WHERE {?s ?p ?o}
__HERE__


  local tmpbasic="$(mktemp ${TMPDIR}/basic.XXXXXX.ttl)"
  cat >"${tmpbasic}" << __HERE__
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix lcc-lr: <https://www.omg.org/spec/LCC/Languages/LanguageRepresentation/> .
@prefix lcc-cr: <https://www.omg.org/spec/LCC/Countries/CountryRepresentation/> .

__HERE__


  local lcccr="$(mktemp ${TMPDIR}/LCCCR.XXXXXX.nt)"
  local lcccc="$(mktemp ${TMPDIR}/LCCCC.XXXXXX.nt)"
  
  ${JENA_ARQ} \
      --query=${tmpflatecho} \
      --data="${INPUT}/LCC/Countries/CountryRepresentation.rdf" \
      --results=NT \
      > "$lcccr"
  ${JENA_ARQ} \
      --query=${tmpflatecho} \
      --data="${INPUT}/LCC/Languages/LanguageRepresentation.rdf" \
      --results=NT \
      > "$lcccc"

  local prefixes="$(mktemp ${TMPDIR}/prefixes.XXXXXX)"

  local tmpmodule="$(mktemp ${TMPDIR}/module.XXXXXX.nt)"


  log "starting buildquads with the new quadify"



  (
    cd ${ontology_product_tag_root}
	  echo "starting dev"

	  ${FIND} . -mindepth 2 -name '*.ttl' -print | while read file; do quadify "$file"; done > "${DevQuadsFile}"
	  echo "starting prod"
	  ${GREP} -rl 'fibo-fnd-utl-av:hasMaturityLevel fibo-fnd-utl-av:Release' | \
	      while read file ; do quadify $file ; done > ${ProdQuadsFile}
     set -x
	  ${FIND} ${INPUT} -name "Metadata*.rdf" -exec \
               ${JENA_RIOT} \
                 --syntax=RDF/XML {} \; \
		 > ${tmpmodule}

  )

  log "finished buildquads"

  return 0
  }
  
  function createQuickVersions() {

  setProduct ontology || return $?


  log "Getting metadata"
  "${JENA_ARQ}" $(find "${source_family_root}" -name "Metadata${ONTPUB_FAMILY^^}.rdf" | grep -v "/etc/" | sed "s/^/--data=/") \
    --query=/publisher/lib/metadata.sparql \
    --results=TTL > "${TMPDIR}/metadata.ttl"

  #
  # Get ontologies for Dev
  #
  log "Merging all dev ontologies into one RDF file"
  robot merge --input "${source_family_root}/${DEV_SPEC}" --output ${TMPDIR}/pre_dev.${ONTPUB_FAMILY}-quickstart.owl
 
  ${JENA_ARQ} \
    --data ${TMPDIR}/metadata.ttl \
    --data ${TMPDIR}/pre_dev.${ONTPUB_FAMILY}-quickstart.owl \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > ${tag_root}/dev.${ONTPUB_FAMILY}-quickstart.ttl

  #
  # Get ontologies for Prod
  #
  log "Merging all prod ontologies into one RDF file"
  robot merge --input "${source_family_root}/${PROD_SPEC}" --output ${TMPDIR}/pre_prod.${ONTPUB_FAMILY}-quickstart.owl

  
  ${JENA_ARQ} \
    --data ${TMPDIR}/metadata.ttl \
    --data ${TMPDIR}/pre_prod.${ONTPUB_FAMILY}-quickstart.owl \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > ${tag_root}/prod.${ONTPUB_FAMILY}-quickstart.ttl
	
  ${JENA_ARQ} --data=${tag_root}/dev.${ONTPUB_FAMILY}-quickstart.ttl --query=/publisher/lib/echo.sparql --results=NT > ${tag_root}/dev.${ONTPUB_FAMILY}-quickstart.nt  
  ${JENA_ARQ} --data=${tag_root}/prod.${ONTPUB_FAMILY}-quickstart.ttl --query=/publisher/lib/echo.sparql --results=NT > ${tag_root}/prod.${ONTPUB_FAMILY}-quickstart.nt
  
  zip ${tag_root}/dev.${ONTPUB_FAMILY}-quickstart.ttl.zip ${tag_root}/dev.${ONTPUB_FAMILY}-quickstart.ttl
  zip ${tag_root}/prod.${ONTPUB_FAMILY}-quickstart.ttl.zip ${tag_root}/prod.${ONTPUB_FAMILY}-quickstart.ttl
  zip ${tag_root}/dev.${ONTPUB_FAMILY}-quickstart.nt.zip ${tag_root}/dev.${ONTPUB_FAMILY}-quickstart.nt
  zip ${tag_root}/prod.${ONTPUB_FAMILY}-quickstart.nt.zip ${tag_root}/prod.${ONTPUB_FAMILY}-quickstart.nt

}
