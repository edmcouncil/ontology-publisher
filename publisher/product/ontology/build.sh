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
  ontologyConvertMarkdownToHtml || return $?
  ontologyBuildIndex  || return $?
  ontologyCreateAboutFiles || return $?
#  if ((speedy)) ; then
#    log "speedy=true -> Not doing some conversions because they are slow"
#  else
    ontologyConvertRdfToAllFormats || return $?
#  fi
  ontologyCreateTheAllTtlFile || return $?
  #
  # JG>Who's using "ontology-zips.log"?
  #
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

  find "${source_family_root}/etc" -name 'testHygiene*.sparql'
}

#
# JG>Dean, I just copied the code from the old hygiene test into this function...
#
function runHygieneTests() {

  local banner

  setProduct ontology || return $?

  #
  # Get ontologies for Dev
  #
  log "Merging all dev ontologies into one RDF file: $(logFileName ${tag_root}/DEV.ttl)"
  "${JENA_ARQ}" $(find "${source_family_root}" -name "*.rdf" | grep -v "/etc/" | sed "s/^/--data=/") \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > ${tag_root}/DEV.ttl

  #
  # Get ontologies for Prod
  #
  log "Merging all prod ontologies into one RDF file: : $(logFileName ${tag_root}/PROD.ttl)"
  "${JENA_ARQ}" \
    $(grep -r 'utl-av[:;.]Release' "${source_family_root}" | sed 's/:.*$//;s/^/--data=/' | grep -F ".rdf") \
    --query=/publisher/lib/echo.sparql \
    --results=TTL > ${tag_root}/PROD.ttl

  logRule "Will run the following tests:"

  while read -r hygieneTestSparqlFile ; do
    banner=$(getBannerFromSparqlTestFile "${hygieneTestSparqlFile}")
    logItem "$(basename "${hygieneTestSparqlFile}")" "${banner}"
  done < <(getHygieneTestFiles)

  logRule "Errors in DEV:"

  while read -r hygieneTestSparqlFile ; do
    banner=$(getBannerFromSparqlTestFile "${hygieneTestSparqlFile}")
    logItem "Running test" "${banner}"
    ${JENA_ARQ} \
      --data=${tag_root}/DEV.ttl \
      --results=csv \
      --query="${hygieneTestSparqlFile}" | \
      grep -v "^s,o,error$" | \
      grep -v "^error$" | \
      sed 's/PRODERROR/WARN/g' > \
      ${TMPDIR}/console1.txt
    cat ${TMPDIR}/console1.txt
  done < <(getHygieneTestFiles)

  logRule "Errors in PROD:"

  while read -r hygieneTestSparqlFile ; do
    banner=$(getBannerFromSparqlTestFile "${hygieneTestSparqlFile}")
    logItem "Running test" "${banner}"
    ${JENA_ARQ} \
      --data=${tag_root}/PROD.ttl \
      --results=csv \
      --query="${hygieneTestSparqlFile}" | \
      grep -v "^s,o,error$" | \
      grep -v "^error$" | \
      sed 's/PRODERROR/ERROR/g' > \
      ${TMPDIR}/console2.txt
    cat ${TMPDIR}/console2.txt
  done < <(getHygieneTestFiles)

  grep "ERROR:" ${TMPDIR}/console1.txt && return 1
  grep "ERROR:" ${TMPDIR}/console2.txt && return 1

  rm ${TMPDIR}/console1.txt
  rm ${TMPDIR}/console2.txt

  logRule "Passed all the hygiene tests"

  return 0
}

#
# Copy all publishable files from the fibo repo to the appropriate target directory (${tag_root})
# where they will be converted to publishable artifacts
#
function ontologyCopyRdfToTarget() {

  require source_family_root || return $?
  require tag_root || return $?

  local module
#  local upperModule

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

  #
  # Rename the lower case module directories as we have them in the fibo git repo to
  # upper case directory names as we serve them on spec.edmcouncil.org
  #
#  log "Rename all lower case module directories to upper case and remove unpublished directories:"
#  (
#    cd "${tag_root}" || return $?
#    while read -r module ; do
#      [ "${module}" == "./etc" ] && continue
##     [ "${module}" == "./ext" ] && continue
#      upperModule="${module^^}"
#      [ "${module}" == "${upperModule}" ] && continue
#      #
#      # Mv in two steps to avoid the error
#      # "cannot move X to a subdirectory of itself"
#      #
#      if ! mv -f "${module}" "${module}_upper" ; then
#        error "Cannot rename ${module} to ${module}_upper"
#        return 1
#      fi
#      if ! mv -f "${module}_upper" "${upperModule}" ; then
#        error "Cannot rename ${module}_upper to ${upperModule}"
#        return 1
#      fi
#    done < <(find . -maxdepth 1 -mindepth 1 -type d)
#    export modules=""
#    export module_directories=""
#    while read -r module ; do
#      [ "${module}" == "./etc" ] && continue
##     [ "${module}" == "./ext" ] && continue
#      export modules="${modules} ${module/.\//}"
#      export module_directories="${module_directories} $(readlink -f "${module}")"
#    done < <(find . -maxdepth 1 -mindepth 1 -type d)
#    logVar modules
#  )
  #
  # Clean up a few things that are too embarrassing to publish
  #
  #rm -vrf ${tag_root}/etc >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/cm >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/data >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/image >/dev/null 2>&1
#  rm -vrf ${tag_root}/etc/imports >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/infra >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/odm >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/operational >/dev/null 2>&1
#  rm -vrf ${tag_root}/etc/process >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/source >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/spec >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/testing >/dev/null 2>&1
  rm -vrf ${tag_root}/etc/uml >/dev/null 2>&1
  rm -vrf ${tag_root}/**/archive >/dev/null 2>&1
  rm -vrf ${tag_root}/**/Bak >/dev/null 2>&1

  #${FIND} ${tag_root}

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
# - https://spec.edmcouncil.org/fibo/ontology/BE/20150201/
#
# with
#
# - https://spec.edmcouncil.org/fibo/ontology/BE/
#
s@${product_root_url}/\([A-Z]*\)/[0-9]*/@${product_root_url}/\1/@g
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

function ontologyConvertMarkdownToHtml() {

  logStep "ontologyConvertMarkdownToHtml"

  if ((pandoc_available == 0)) ; then
    error "Could not convert Markdown files to HTML since pandoc is missing"
    return 0 # Ignoring this error though
  fi

  (
    cd "${tag_root}" || return $?

    for markdownFile in **/*.md ; do
      ontologyIsInTestDomain "${markdownFile}" || continue
      log "Convert ${markdownFile} to html"
      ${pandoc_bin} --quiet --standalone --from markdown --to html -o "${markdownFile/.md/.html}" "${markdownFile}"
    done
  )
  return $?
}

#
# The "index" of fibo is a list of all the ontology files, in their
# directory structure.  This is an attempt to automatically produce
# this.
#
function ontologyBuildIndex () {

  require tag_root || return $?
  require tag_root_url || return $?
  require GIT_TAG_NAME || return $?

  logStep "build tree.html files"

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
            -e "s@>Directory Tree<@>FIBO Ontology file directory ${directory/.\//}<@g" \
            -e 's@h1>\n<p>@h1><p>This is the directory structure of FIBO; you can download individual files this way.  To load all of FIBO, please follow the instructions for particular tools at <a href="http://spec.edmcouncil.org/fibo">the main fibo download page</a>.<p/>@' \
            -e "s@<a href=\".*>${spec_root_url}/.*</a>@@" > tree.html
  	  )
  	done < <(${FIND} . -type d)
	)

	return $?
}

#
# Now use the rdf-toolkit serializer to create copies of all .rdf files in all the supported RDF formats
#
# Using the Sesame serializer, here's the documentation:
#
# https://github.com/edmcouncil/rdf-toolkit/blob/master/docs/SesameRdfFormatter.md
#
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
#    zip -r ${zipttlDevFile} "${family_product_branch_tag}" -x \*.rdf \*.zip  \*.jsonld \*AboutFIBOProd.ttl etc
#    zip -r ${ziprdfDevFile} "${family_product_branch_tag}" -x \*.ttl \*.zip \*.jsonld \*AboutFIBOProd.rdf etc
#    zip -r ${zipjsonldDevFile} "${family_product_branch_tag}" -x \*.ttl \*.zip \*.rdf \*AboutFIBOProd.jsonld etc

    ${FIND}  "${family_product_branch_tag}" -name '*.ttl' -print | ${GREP} -v etc |  ${GREP} -v "LoadFIBOProd.ttl" | grep -v About |  xargs zip ${zipttlDevFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipttlDevFile}

    ${FIND}  "${family_product_branch_tag}" -name '*.rdf' -print | ${GREP} -v etc | ${GREP} -v "LoadFIBOProd.rdf" |  grep -v About |xargs zip ${ziprdfDevFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${ziprdfDevFile}

    ${FIND}  "${family_product_branch_tag}" -name '*.jsonld' -print | ${GREP} -v etc | ${GREP} -v "LoadFIBOProd.jsonld" |  grep -v About |  xargs zip ${zipjsonldDevFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipjsonldDevFile}


    

    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".ttl" | ${SED} 's/:.*$//' | xargs zip -r ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*Load*.ttl' -print | ${GREP} -v "LoadFIBODev.ttl" |  xargs zip ${zipttlProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipttlProdFile}
    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".rdf" |   ${SED} 's/:.*$//' | xargs zip -r ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*Load*.rdf' -print | ${GREP} -v "LoadFIBODev.rdf" | xargs zip ${ziprdfProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${ziprdfProdFile}
    ${GREP} -r 'utl-av[:;.]Release' "${family_product_branch_tag}" | ${GREP} -F ".jsonld" |   ${SED} 's/:.*$//' | xargs zip -r ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*Load*.jsonld' -print | ${GREP} -v "LoadFIBODev.jsonld" | xargs zip ${zipjsonldProdFile}
    ${FIND}  "${family_product_branch_tag}" -name '*catalog*.xml' -print | xargs zip ${zipjsonldProdFile}

  )

  log "Step: ontologyZipFiles finished"

  return 0
}

function buildquads () {

  local ProdQuadsFile="${tag_root}/prod.fibo.nq"
  local DevQuadsFile="${tag_root}/dev.fibo.nq"

  local ProdFlatNT="${tag_root}/prod.fibo-quickstart.nt"
  local DevFlatNT="${tag_root}/dev.fibo-quickstart.nt"

  local ProdFlatTTL="${tag_root}/prod.fibo-quickstart.ttl"
  local DevFlatTTL="${tag_root}/dev.fibo-quickstart.ttl"

  local ProdTMPTTL="$(mktemp ${TMPDIR}/prod.temp.XXXXXX.ttl)"
  local DevTMPTTL="$(mktemp ${TMPDIR}/dev.temp.XXXXXX.ttl)"

  local CSVPrefixes="${tag_root}/prefixes.fibo.csv"
  local TTLPrefixes="${tag_root}/prefixes.fibo.ttl"
  local SPARQLPrefixes="${tag_root}/prefixes.fibo.sq"


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
@prefix lcc-lr: <https://www.omg.org/spec/LCC/Languages/LanguageRepresentation/>
@prefix lcc-cr: <https://www.omg.org/spec/LCC/Countries/CountryRepresentation/>

__HERE__


  local lcccr="$(mktemp ${TMPDIR}/LCCCR.XXXXXX.nt)"
  local lcccc="$(mktemp ${TMPDIR}/LCCCC.XXXXXX.nt)"
  
  ${JENA_ARQ} \
      --query=${tmpflatecho} \
      --data=${INPUT}/LCC/Countries/CountryRepresentation.rdf \
      --results=NT \
      > "$lcccr"
  ${JENA_ARQ} \
      --query=${tmpflatecho} \
      --data=${INPUT}/LCC/Languages/LanguageRepresentation.rdf \
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

	  cat $lcccr > ${ProdFlatNT}
	  cat $lcccc >> ${ProdFlatNT}


	  cat $lcccr > ${DevFlatNT}
	  cat $lcccc >> ${DevFlatNT}


	  
	  ${JENA_ARQ} \
               --query="${tmpflat}" \
               --data=${ProdQuadsFile} \
	       --data=${tmpmodule}  \
               --results=NT                >> ${ProdFlatNT}
	  ${JENA_ARQ} \
               --query="${tmpflat}" \
               --data=${DevQuadsFile}  \
	       --data=${tmpmodule}  \
               --results=NT 		   >> ${DevFlatNT}

	  ${JENA_ARQ} \
               --query="${tmppx}" \
	       --data=${DevQuadsFile} \
	       --results=CSV |\
                   tail +2 |\
                   tr --delete "\015"     > ${prefixes}

	  cat ${prefixes} > "${CSVPrefixes}"
	  cat ${prefixes} > "${SPARQLPrefixes}"
	  cat ${tmpbasic} > ${TTLPrefixes} 
	  sed 's/^/@/;s/$/ ./' ${prefixes} >> ${TTLPrefixes}
	  

	  cat > "${ProdTMPTTL}" <<EOF
<${tag_root_url}/Prod.fibo-quickstart> a owl:Ontology .
EOF

	  cat > "${DevTMPTTL}" <<EOF
<${tag_root_url}/Dev.fibo-quickstart> a owl:Ontology .
EOF

	  
	  cat ${TTLPrefixes} ${ProdFlatNT} > "${ProdTMPTTL}"

	  cat ${TTLPrefixes} ${DevFlatNT} > "${DevTMPTTL}"

          

	  
	  ${JENA_ARQ} --data="${ProdTMPTTL}" --query="${tmpecho}" --results=TTL > "${ProdFlatTTL}"
	  ${JENA_ARQ} --data="${DevTMPTTL}" --query="${tmpecho}" --results=TTL > "${DevFlatTTL}"
	  

	  zip ${ProdQuadsFile}.zip ${ProdQuadsFile}
	  zip ${DevQuadsFile}.zip ${DevQuadsFile}

	  zip ${ProdFlatNT}.zip ${ProdFlatNT}
	  zip ${DevFlatNT}.zip ${DevFlatNT}


	  
  )

  log "finished buildquads"

  return 0
}
