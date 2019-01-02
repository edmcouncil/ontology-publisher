#!/usr/bin/env bash
#
# Generate the widoco "product" from the source ontologies
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

export SCRIPT_DIR="${SCRIPT_DIR}" # Yet another hack to silence IntelliJ
export speedy="${speedy:-0}"

#
# Publish the widoco product which depends on the ontology product, so that should have been built before
#
function publishProductWidoco() {

  setProduct ontology || return $?
  ontology_product_tag_root="${tag_root:?}"

  setProduct widoco || return $?
  widoco_product_tag_root="${tag_root:?}"

  logItem "Widoco Root" "$(logFileName "${widoco_product_tag_root}")"

  widoco_script_dir="$(cd "${SCRIPT_DIR}/product/widoco" && pwd)"

  logItem "Widoco Scripts" "${widoco_script_dir}"

  buildVowlIndex || return $?

  generateWidocoLog4jConfig || fileAbbreviationreturn $?

  generateWidocoDocumentation ${ontology_product_tag_root} || return $?

  return 0
}

function generateWidocoLog4jConfig() {

  cat > ${TMPDIR}/widoco-log4j2.xml << __HERE__
<?xml version="1.0" encoding="UTF-8"?>
<configuration status="warn" name="Widoco" packages="">
  <appenders>
    <File name="WidocoLog" fileName="widoco.log">
      <PatternLayout>
        <pattern>%d %p %C{1.} [%t] %m%n</pattern>
      </PatternLayout>
    </File>
  </appenders>
  <loggers>
    <root level="trace">
      <appender-ref ref="WidocoLog"/>
    </root>
  </loggers>
</configuration>
__HERE__

}

function generateWidocoDocumentation() {

  local -r directory="$(cd $1 && pwd -L)"

  #logRule "Running widoco in $(logFileName "${directory}")"

  (
    cd "${directory}" || return $?

    local -r directories="$(find . -mindepth 1 -maxdepth 1 -type d)"
    if [ -z "${directories}" ] ; then
      log "Directory $(pwd) has no subdirectories"
    else
      for directoryEntry in ${directories} ; do
        generateWidocoDocumentation "${directoryEntry}"
      done
    fi

    if ls *.ttl >/dev/null 2>&1 ; then
      while read ontologyFile ; do
        generateWidocoDocumentationForFile "${directory}" "${ontologyFile}"
      done < <(ls -1 *.ttl)
    else
      warning "Directory $(pwd) does not have any turtle files to process"
    fi
  )

  return $?
}

function widocoLauncherJar() {

  if [ -f /usr/share/java/widoco/widoco-launcher.jar ] ; then
    echo -n "/usr/share/java/widoco/widoco-launcher.jar"
  else
    error "Could not find Widoco jar"
    return 1
  fi

  return 0
}

function generateWidocoDocumentationForFile() {

  local -r directory="$1"
  local -r outputDir="${directory/ontology/widoco}"
  local -r turtleFile="$2"
  local -r baseName="$(basename "${turtleFile}")"
  local -r rdfFileNoExtension="${turtleFile/.ttl/}"
  local widocoJar ; widocoJar="$(widocoLauncherJar)" || return $?

  local -r extension="$([[ "${turtleFile}" = *.* ]] && echo ".${turtleFile##*.}" || echo '')"

  logRule "Running widoco in $(logFileName "${directory}")"

  case "${baseName}" in
    Metadata*)
      return 0
      ;;
    *)
      ;;
  esac

  if [[ "${turtleFile}" =~ ^[0-9].* || "${turtleFile}" =~ ^About.* ]] ; then
    logItem  "skipping" "$(logFileName "${turtleFile}") in $(logFileName "${directory}") with extension ${extension}"
    return 0
  fi

  logItem "Widoco processes"  "$(logFileName "${turtleFile}")"
  logItem "Current Directory" "$(logFileName "${directory}")"
  logItem "Output Directory"  "$(logFileName "${outputDir}")"

  mkdir -p "${outputDir}" >/dev/null 2>&1 || return $?

  if [ "${turtleFile}" = "AboutFIBODev.ttl" ] || [ "${turtleFile}" = "Corporations.ttl" ] ; then
    log "Printing contents of file ${turtleFile} "
    cat "${turtleFile}" | pipelog
  fi

  #    -licensius \

  java \
    -classpath /usr/share/java/log4j/log4j-core.jar:/usr/share/java/log4j/log4j-1.2-api.jar:/usr/share/java/log4j/log4j-api.jar \
    -Dxxx=widoco \
    -Xmx4g \
    -Xms4g \
    -Dfile.encoding=UTF-8 \
    -Dlog4j.configurationFile=${TMPDIR}/widoco-log4j2.xml \
    -Dorg.apache.logging.log4j.simplelog.StatusLogger.level=TRACE \
    -jar "${widocoJar}" \
    -ontFile "${turtleFile}" \
    -outFolder "${outputDir}/${rdfFileNoExtension}" \
    -rewriteAll \
    -doNotDisplaySerializations \
    -displayDirectImportsOnly \
    -lang en  \
    -getOntologyMetadata \
    -webVowl 2>&1 | \
    grep -v 'WIzard' | \
    grep -v 'https://w3id.org/widoco/' | \
    grep -v 'Generating documentation' | \
    grep -v 'No previous version provided' | \
    grep -v 'Error while reading configuration properties' | \
    grep -v 'Unrecognized conversion specifier' | \
    grep -v 'Unrecognized format specifier' | \
    grep -v 'http://www.licensius.com'
  local -r rc=${PIPESTATUS[0]}
  log " - rc is ${rc}"

  find ${outputDir} -ls

  # KG: Break on first failure - testing INFRA-229

  if [ ${rc} -ne 0 ] ; then
    error "Could not run widoco on ${turtleFile} "
    #log "Printing contents of file ${rdfFile} "
    #contents=$(<${rdfFile})
    #log "${contents}"

    mkdir -p "${outputDir}/${rdfFileNoExtension}"
    cp "${widoco_script_dir}/widoco-sections/index-en.html" "${outputDir}/${rdfFileNoExtension}" || echo $?
    ${SED} -i "s/OntologyName/${rdfFileNoExtension}/g" "${outputDir}/${rdfFileNoExtension}/index-en.html" || echo $?
    #
    # JG>I commented this line below out because I do not se where the file failedOntologies is being used and
    #    it can't be written in the container to the read-only directory SCRIPT_DIR
    #
    #echo ${directory} "${rdfFileNoExtension}" >> "${SCRIPT_DIR}/failedOntologies"
  fi

  #
  # Remove introduction section
  #
  if [ -f "${outputDir}/${rdfFileNoExtension}/index-en.html" ] ; then

    if [ "${turtleFile}" = "AboutFIBODev.ttl" ] || [ "${turtleFile}" = "Corporations.ttl" ] ; then
      log "Printing contents of file before modification ${outputDir}/${rdfFileNoExtension}/index-en.html "
      cat "${outputDir}/${rdfFileNoExtension}/index-en.html"
    fi
    #contents=$(<${outputDir}/${rdfFileNoExtension}/index-en.html)
    #log "contents of index file before modification"
    #log "${contents}"

    log "Replacing introduction with acknowledgements section from file ${outputDir}/${rdfFileNoExtension}/index-en.html"
    log "Contents of widoco-sections folder ${widoco_script_dir/${WORKSPACE}/}/widoco-sections"
    ls -al ${widoco_script_dir}/widoco-sections
    ${CP} "${widoco_script_dir}/widoco-sections/acknowledgements-en.html" "${outputDir}/${rdfFileNoExtension}/sections"
    log "Contents of folder ${outputDir}/${rdfFileNoExtension}/sections"
    ls -al "${outputDir}/${rdfFileNoExtension}/sections"
    ${SED} -i "s/#introduction/#acknowledgements/g" "${outputDir}/${rdfFileNoExtension}/index-en.html"
    ${SED} -i "s/introduction-en/acknowledgements-en/g" "${outputDir}/${rdfFileNoExtension}/index-en.html"
    log "Removing description section from file ${outputDir}/${rdfFileNoExtension}/index-en.html"
    ${SED} -i "/#description/d" "${outputDir}/${rdfFileNoExtension}/index-en.html"
    log "Removing references section from file ${outputDir}/${rdfFileNoExtension}/index-en.html"
    ${SED} -i "/#references/d" "${outputDir}/${rdfFileNoExtension}/index-en.html"
    log "Replace the default image for license with the MIT license image"
    ${SED} -i "s/https:\/\/img.shields.io\/badge\/License-license name goes here-blue.svg/https:\/\/img.shields.io\/github\/license\/mashape\/apistatus.svg/g" "${outputDir}/${rdfFileNoExtension}/index-en.html"
    # log "Replacing anchor tags generated improperly in the imported ontologies section"
    # ${SED} -i 's@\(<a[^>]*>\)<\([^>]*\)></a>@\1\2</a>@g' "${outputDir}/${rdfFileNoExtension}/index-en.html"
    # log "Removing anchor tags for skos core generated improperly in the imported ontologies section"
    # ${SED} -i 's@\(<a[^>]*>\)core</a>@@g' "${outputDir}/${rdfFileNoExtension}/index-en.html"

    if [ "${turtleFile}" = "AboutFIBODev.ttl" -o "${turtleFile}" = "Corporations.ttl" ] ; then
      log "Printing contents of file after modification ${outputDir}/${rdfFileNoExtension}/index-en.html "
      cat "${outputDir}/${rdfFileNoExtension}/index-en.html"
    fi

    return 0

  else
    log "No file found at ${outputDir}/${rdfFileNoExtension}/index-en.html"
  fi

  # KG: Need to figure out why it fails on fibo/ontology/master/latest/SEC/SecuritiesExt/SecuritiesExt.ttl
  #
  # KG: Commenting out temporarily so that the build doesn't stop
  #
  #if [ ${PIPESTATUS[0]} -ne 0 ] ; then
  #  error "Could not run widoco on $1/$i "
  #  return 1
  #fi

  return 0
}

#
# Called by buildVowlIndex() exclusively
#
function buildVowlIndexInvokeTree() {

  local -r title="$1"
  local -r type="$2" # RELEASE or empty
  local -r outputFile="$3"

  #
  # KG>Do we need this -I '*Ext'
  # JG>I don't know, PR knows more about this
  #
  ${TREE} \
    -P "*.rdf${type}" \
    -I  "[0-9]*|*Ext|About*|All*|Metadata*" \
    -T "${title}" \
    --noreport \
    --dirsfirst \
    -H "${tag_root_url}" | \
    ${SED} \
      -e "s@${GIT_BRANCH}\/${GIT_TAG_NAME}\/\(/[^/]*/\)@${GIT_BRANCH}\/${GIT_TAG_NAME}/\\U\\1@" \
      -e "s@\(${product_branch_tag}/.*\)\.rdf${type}\">@\1/index-en.html\">@" \
      -e "s@rdf${type}@rdf@g" \
      -e 's@\(.*\).rdf@\1 vowl@' \
      -e 's/<a[^>]*\/\">\([^<]*\)<\/a>/\1/g' \
      -e 's/.VERSION { font-size: small;/.VERSION { display: none; font-size: small;/g' \
      -e 's/BODY {.*}/BODY { font-family : \"Courier New\"; font-size: 12pt ; line-height: 0.90}/g' \
      -e 's/ariel/\"Courier New\"/g' \
      -e 's/<hr>//g' \
      -e "s@>Directory Tree<@>${title}<@g" \
      -e 's@h1><p>@h1><p>The Visual Notation for OWL Ontologies (VOWL) defines a visual language for the user-oriented representation of ontologies. It provides graphical depictions for elements of the Web Ontology Language (OWL) that are combined to a force-directed graph layout visualizing the ontology.<br/>This specification focuses on the visualization of the ontology schema (i.e. the classes, properties and datatypes, sometimes called TBox), while it also includes recommendations on how to depict individuals and data values (the ABox). FIBO uses open source software named WIDOCO (Wizard for DOCumenting Ontologies) for <a href="https://github.com/dgarijo/Widoco">VOWL</a>.<p/>@' \
      -e 's@<a href=".*>https://spec.edmcouncil.org/.*</a>@@' > "${outputFile}"
}

#
# The vowl "index" of fibo is a list of all the ontology files, in their
# directory structure and link to the vowl documentation.  This is an attempt to automatically produce
# this.
#
function buildVowlIndex () {

  local -r vowlTreeP="${widoco_product_tag_root}/vowltreeProd.html"
  local -r vowlTreeD="${widoco_product_tag_root}/vowltreeDev.html"
  local -r vowlTreeDjson="${widoco_product_tag_root}/vowltreeDev.json"
  local -r titleP="FIBO Widoco File Directory (Production)"
  local -r titleD="FIBO Widoco File Directory (Development)"

  logRule "Step: buildVowlIndex (${vowlTree/${WORKSPACE}/})"

  logVar vowlTree
  logVar vowlTreeP
  logVar vowlTreeD
  logVar titleP
  logVar titleD

  (
    cd "${ontology_product_tag_root}" || return $?
    logItem "Ontology Root" "${ontology_product_tag_root/${WORKSPACE}/}"

    logVar tag_root_url
    logVar GIT_BRANCH
    logVar GIT_TAG_NAME
    logVar product_branch_tag

    buildVowlIndexInvokeTree "${titleD}" "" "${vowlTreeD}"

#   log "Printing contents of tree ${vowlTreeD}"
#   contents=$(<${vowlTreeD})
#   echo ${contents}

    log "Suppressing failed Ontology Links"
    #
    # PR>Leaving the logic here in case there are further widoco failures later
    #
    failedOntologies="XXXXX"
    IFS=',' read -ra FAILED_ONTOLOGIES <<< "$failedOntologies"
    for i in "${FAILED_ONTOLOGIES[@]}"; do
      ${SED} -i "s/<a.*\/$i\/index-en\.html\">\([^<]*\) vowl<\/a>/\1/g" "${vowlTreeD}"
    done

    local pfiles ; pfiles="$(mktempWithExtension pfiles txt)" || return $?

    ${GREP} -rl 'utl-av[:;.]Release' . > ${pfiles}
    cat ${pfiles} | while read file ; do mv ${file} ${file}RELEASE ; done

    log "Generating Production Widoco Tree"
    buildVowlIndexInvokeTree "${titleP}" "RELEASE" "${vowlTreeP}"

    cat ${pfiles} | while read file ; do mv ${file}RELEASE ${file} ; done
    rm ${pfiles}

    #
    # Also create a JSON version of the tree file so that we can later easily add a browsing function to the new
    # SPA (single page application) front end
    #
    ${TREE} -J -P '*.rdf' > "${vowlTreeDjson}"
  )

	return 0
}
