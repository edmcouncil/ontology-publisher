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

declare -r -g test_widoco=0

#
# Publish the widoco product which depends on the ontology product, so that should have been built before
#
function publishProductWidoco() {

  setProduct ontology || return $?
  ontology_product_tag_root="${tag_root:?}"
  ontology_tag_root_url="${tag_root_url:?}"
  ontology_product_root_url="${product_root_url:?}"

  setProduct widoco || return $?
  widoco_product_tag_root="${tag_root:?}"

  widoco_script_dir="$(cd "${SCRIPT_DIR}/product/widoco" && pwd)"

  logDir widoco_product_tag_root
  logDir widoco_script_dir
  #
  # Build the "vowltreeDev.html" and "vowltreeProd.html" files.
  #
  # JG>Dean, those file names are terribly ugly. Not only mixed case but also mixing vowl and widoco as two
  #    product names is not really consistent. Should be all widoco. We can do vowl separately next to widoco later.
  #    Also, I think that vowltreeDev.html should be just index.html (and look much better, but not only that,
  #    also show the maturity level (prod or dev) in a column or filter it on/off)
  #
  ((test_widoco)) || buildVowlIndex || return $?

  generateWidocoLog4jConfig || return $?
  generateWidocoLog4j2Config || return $?

  logStep "generateWidocoDocumentation"
  #
  # Seems that widoco can leave tmp* directories around in the output ontology directories,
  # so if we are rerunning widoco we better make sure that those temporary directories are
  # all gone.
  #
  # shellcheck disable=SC2038
  find "${ontology_product_tag_root}" -type d -name 'tmp*' | xargs rm -rf

  if ((test_widoco)) ; then
    testWidoco
  else
    generateWidocoDocumentation "${ontology_product_tag_root}"
  fi
  local -r rc=$?

  #
  # And do it again afterwards as well
  #
  # shellcheck disable=SC2038
  find "${ontology_product_tag_root}" -type d -name 'tmp*' | xargs rm -rf

  return ${rc}
}

function generateWidocoLog4jConfig() {

  #
  # Don't overwrite an existing one created by a previous (or parallel) run of this script
  #
#  [[ -f "${TMPDIR}/widoco-log4j.properties" ]] && return 0

  logItem "Widoco log4j config" "$(logFileName "${TMPDIR}/widoco-log4j.properties")"

  cat > "${TMPDIR}/widoco-log4j.properties" << __HERE__
log4j.rootLogger=INFO, stdlog

log4j.appender.stdlog=org.apache.log4j.ConsoleAppender
log4j.appender.stdlog.target=System.err
log4j.appender.stdlog.layout=org.apache.log4j.PatternLayout
log4j.appender.stdlog.layout.ConversionPattern=%d{HH:mm:ss} %-5p %-20c{1} :: %m%n
log4j.appender.stdout.Threshold=ALL

log4j.appender.org.apache.logging.log4j.simplelog.StatusLogger.level=INFO

log4j.appender.org.semanticweb.owlapi=ALL
log4j.appender.widoco.JenaCatalogIRIMapper=INFO

log4j.logger.org.semanticweb.owlapi=INFO
log4j.logger.org.semanticweb.owlapi.util.SAXParsers=OFF
log4j.logger.org.semanticweb.owlapi.utilities.Injector=OFF
log4j.logger.org.semanticweb.owlapi.rdf.rdfxml.parser.TripleHandlers=OFF
log4j.logger.org.eclipse.rdf4j.rio=OFF
#
__HERE__

  return 0
}

function generateWidocoLog4j2Config() {

  cat > "${TMPDIR}/widoco-log4j2.xml" << __HERE__
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

  return 0
}

#
# This function is called recursively so do not add "logRule" in here
#
function generateWidocoDocumentation() {

  local -r directory="$(cd $1 && pwd -L)"

  (
    cd "${directory}" || return $?

    local -r directories="$(find . -mindepth 1 -maxdepth 1 -type d)"
    if [[ -z "${directories}" ]] ; then
      verbose "Directory $(pwd) has no subdirectories"
    else
      for directoryEntry in ${directories} ; do
        generateWidocoDocumentation "${directoryEntry}" || return $?
      done
    fi

    if getDevOntologiesInTurtleFormatInCurrentDirectory >/dev/null 2>&1 ; then
      while read ontologyFile ; do
        generateWidocoDocumentationForFile "${directory}" "${ontologyFile}" || return $?
      done < <(getDevOntologiesInTurtleFormatInCurrentDirectory)
    else
      warning "Directory $(pwd) does not have any .ttl files to process"
    fi
  )

  #
  # uncomment this exit here if you just want to run widoco on the first ontology for testing
  # exit

  return $?
}

function widocoLauncherJar() {

  if [[ -f /usr/share/java/widoco/widoco-launcher.jar ]] ; then
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
  local -r ontologyFile="$2"
  local -r rdfFileNoExtension="${ontologyFile/.ttl/}"
  local widocoJar ; widocoJar="$(widocoLauncherJar)" || return $?
  local -r ontologyPolicyFile="${ontology_product_tag_root:?}/ont-policy.rdf"

  local -r extension="$([[ "${ontologyFile}" = *.* ]] && echo ".${ontologyFile##*.}" || echo '')"

  logRule "Running widoco in $(logFileName "${directory}")"

  if [[ \
    "${ontologyFile}" =~ ^[0-9].* || \
    "${ontologyFile}" =~ ^ont-policy.* \
  ]] ; then
    logItem  "skipping" "$(logFileName "${ontologyFile}") in $(logFileName "${directory}") with extension ${extension}"
    return 0
  fi

  logItem "Widoco is processing"  "$(logFileName "${ontologyFile}")"
  logDir  directory
  logDir  outputDir

  mkdir -p "${outputDir}" >/dev/null 2>&1 || return $?

  #    -licensius \

  if [[ ! -f "${TMPDIR}/widoco-log4j.properties" ]] ; then
    error "Missing ${TMPDIR}/widoco-log4j.properties"
    return 1
  fi
  #
  # ont-policy.rdf has to be in current directory unfortunately.
  #
  if [[ ! -f "${ontologyPolicyFile}" ]] ; then
    error "Could not find ${ontologyPolicyFile}"
    return 1
  fi
  cp "${ontologyPolicyFile}" .

  java \
    -classpath /usr/share/java/log4j/log4j-core.jar:/usr/share/java/log4j/log4j-1.2-api.jar:/usr/share/java/log4j/log4j-api.jar \
    -Dxxx=widoco \
    -Xmx4g \
    -Xms4g \
    -Dfile.encoding=UTF-8 \
    -Djdk.xml.entityExpansionLimit=0 \
    -Dlog4j.debug=false \
    -Dlog4j.configuration="file:${TMPDIR}/widoco-log4j.properties" \
    -Dlog4j.configurationFile="file:${TMPDIR}/widoco-log4j2.xml" \
    -jar "${widocoJar}" \
    -ontFile "${ontologyFile}" \
    -outFolder "${outputDir}/${rdfFileNoExtension}" \
    -rewriteAll \
    -doNotDisplaySerializations \
    -displayDirectImportsOnly \
    -lang en  \
    -getOntologyMetadata 2>&1 | \
    grep -v "JenaCatalogIRIMapper.* -> " | \
    grep -v 'WIzard' | \
    grep -v 'https://w3id.org/widoco/' | \
    grep -v 'Generating documentation' | \
    grep -v 'No previous version provided' | \
    grep -v 'Error while reading configuration properties' | \
    grep -v 'Unrecognized conversion specifier' | \
    grep -v 'Unrecognized format specifier' | \
    grep -v 'http://www.licensius.com'
  local -r rc=${PIPESTATUS[0]}
  logItem "Widoco rc" "${rc}"

  if [[ ${rc} -ne 0 ]] ; then
    find ${outputDir} -ls
    error "Could not run widoco (rc == ${rc}) on ${ontologyFile}"
    #log "Printing contents of file ${rdfFile} "
    #contents=$(<${rdfFile})
    #log "${contents}"

    mkdir -p "${outputDir}/${rdfFileNoExtension}"
    cp "${widoco_script_dir}/widoco-sections/index-en.html" "${outputDir}/${rdfFileNoExtension}" || echo $?
    ${SED} -i "s/OntologyName/${rdfFileNoExtension}/g" "${outputDir}/${rdfFileNoExtension}/index-en.html" || echo $?
    #
    # JG>I commented this line below out because I do not see where the file failedOntologies is being used and
    #    it can't be written in the container to the read-only directory SCRIPT_DIR
    #
    #echo ${directory} "${rdfFileNoExtension}" >> "${SCRIPT_DIR}/failedOntologies"
  fi

  widocoRemoveIntroductionSection || return $?
  widocoReplaceOntologyIRIs "${outputDir}/${rdfFileNoExtension}" || return $?

  # KG: Need to figure out why it fails on fibo/ontology/master/latest/SEC/SecuritiesExt/SecuritiesExt.ttl
  #
  # KG: Commenting out temporarily so that the build doesn't stop
  #
  #if [ ${PIPESTATUS[0]} -ne 0 ] ; then
  #  error "Could not run widoco on $1/$i "
  #  return 1
  #fi

  #
  # If webvowl output was generated,
  # remove the default ontologies that come with WebVowl
  #
  if [[ -d "${outputDir}/${rdfFileNoExtension}/webvowl" ]] ; then
    (
      cd "${outputDir}/${rdfFileNoExtension}/webvowl/data" || return $?
      rm -vf foaf.json goodrelations.json muto.json new_ontology.json ontovibe.json personasonto.json sioc.json template.json
    )
  fi

  return 0
}

function widocoOutFolder() {

  local -r  outputDir="$1"
  local     ontFile="$2"

  require ontology_product_tag_root || return $?
  require source_family_root || return $?
  require spec_family_root || return $?

  ontFile="${ontFile/${ontology_product_tag_root}\/}"
  ontFile="${ontFile/${source_family_root}\/}"
  ontFile="${ontFile/${spec_family_root}\/}"
  ontFile="${ontFile%.*}"

  echo -n "${outputDir}/${ontFile}"
}

#
# This function is called when test_widoco=1, it runs widoco only on the CorporateBodies ontology
#
# Widoco Usage: java -jar widoco.jar [-ontFile file] or [-ontURI uri] [-outFolder folderName]
# [-confFile propertiesFile] [-getOntologyMetadata] [-oops] [-rewriteAll] [-crossRef] [-saveConfig configOutFile]
# [-lang lang1-lang2] [-includeImportedOntologies] [-htaccess] [-licensius] [-webVowl] [-ignoreIndividuals]
# [-includeAnnotationProperties] [-analytics analyticsCode] [-doNotDisplaySerializations] [-displayDirectImportsOnly]
# [-rewriteBase rewriteBasePath]
#
function testWidoco() {

  require ontology_product_tag_root || return $?
  require widoco_product_tag_root || return $?
  require source_family_root || return $?
  require spec_family_root || return $?

  local widocoJar ; widocoJar="$(widocoLauncherJar)" || return $?
  local -r outputDir="${widoco_product_tag_root}"
# local -r ontFile="${ontology_product_tag_root}/BE/LegalEntities/CorporateBodies.rdf"
  local -r ontFile="${ontology_product_tag_root}/CAE/CorporateEvents/CorporateActionsEvents.rdf"
  local -r outFolder="$(widocoOutFolder "${outputDir}" "${ontFile}")"

  logVar ontFile
  logVar outFolder

  local -r ontologyPolicyFile="${ontology_product_tag_root:?}/ont-policy.rdf"

  #
  # Ensure that target folder is empty
  #
  rm -rf "${outFolder}" >/dev/null 2>&1

  (
    cd "${TMPDIR}" || return $?
    cp "${ontologyPolicyFile}" .
    java \
      -classpath /usr/share/java/log4j/log4j-core.jar:/usr/share/java/log4j/log4j-1.2-api.jar:/usr/share/java/log4j/log4j-api.jar \
      -Dxxx=widoco \
      --add-opens java.base/java.lang=ALL-UNNAMED \
      -Xmx4g \
      -Xms4g \
      -Dfile.encoding=UTF-8 \
      -Djdk.xml.entityExpansionLimit=0 \
      -Dlog4j.debug=false \
      -Dlog4j.configuration="file:${TMPDIR}/widoco-log4j.properties" \
      -Dlog4j.configurationFile="file:${TMPDIR}/widoco-log4j2.xml" \
      -jar "${widocoJar}" \
      -ontFile "${ontFile}" \
      -outFolder "${outFolder}" \
      -rewriteAll \
      -saveConfig "${outFolder}/config.txt" \
      -doNotDisplaySerializations \
      -includeImportedOntologies \
      -includeAnnotationProperties \
      -lang en  \
      -getOntologyMetadata \
      -webVowl
    local -r rc=$?

    logVar rc
    return ${rc}
  )
  local -r rc=$?

  log "x"
  find "${outFolder}" | pipelog


  return ${rc}
}

#
# Remove introduction section
#
function widocoRemoveIntroductionSection() {

  local -r indexHtml="${outputDir}/${rdfFileNoExtension}/index-en.html"

  if [[ ! -f "${indexHtml}" ]] ; then
    logItem "Not found" "$(logFileName "${indexHtml}")"
    return 0
  fi

  if [[ ! -d "${outputDir}/${rdfFileNoExtension}/sections/" ]] ; then
    error "Directory $(logFileName "${outputDir}/${rdfFileNoExtension}/sections/") does not exist"
    return 1
  fi

  if [[ "${turtleFile}" = "AboutFIBODev.ttl" ]] || [[ "${turtleFile}" = "Corporations.ttl" ]] ; then
    log "Printing contents of file before modification ${outputDir}/${rdfFileNoExtension}/index-en.html "
    cat "${indexHtml}"
  fi
  #contents=$(<${outputDir}/${rdfFileNoExtension}/index-en.html)
  #log "contents of index file before modification"
  #log "${contents}"

  log "Replacing introduction with acknowledgements section from file $(logFileName "${indexHtml}")"

#  log "Contents of widoco-sections folder $(logFileName "${widoco_script_dir}/widoco-sections")"
#  ls -al ${widoco_script_dir}/widoco-sections

  ${CP} "${widoco_script_dir}/widoco-sections/acknowledgements-en.html" "${outputDir}/${rdfFileNoExtension}/sections/"

#  log "Contents of folder ${outputDir}/${rdfFileNoExtension}/sections"
#  ls -al "${outputDir}/${rdfFileNoExtension}/sections"

  ${SED} -i "s/#introduction/#acknowledgements/g" "${indexHtml}"
  ${SED} -i "s/introduction-en/acknowledgements-en/g" "${indexHtml}"
  log "Removing description section from file ${outputDir}/${rdfFileNoExtension}/index-en.html"
  ${SED} -i "/#description/d" "${indexHtml}"
  log "Removing references section from file ${outputDir}/${rdfFileNoExtension}/index-en.html"
  ${SED} -i "/#references/d" "${indexHtml}"
  log "Replace the default image for license with the MIT license image"
  ${SED} -i "s/https:\/\/img.shields.io\/badge\/License-license name goes here-blue.svg/https:\/\/img.shields.io\/github\/license\/mashape\/apistatus.svg/g" "${indexHtml}"

  # log "Replacing anchor tags generated improperly in the imported ontologies section"
  # ${SED} -i 's@\(<a[^>]*>\)<\([^>]*\)></a>@\1\2</a>@g' "${indexHtml}"
  # log "Removing anchor tags for skos core generated improperly in the imported ontologies section"
  # ${SED} -i 's@\(<a[^>]*>\)core</a>@@g' "${indexHtml}"

  if [[ "${turtleFile}" = "AboutFIBODev.ttl" ]] || [[ "${turtleFile}" = "Corporations.ttl" ]] ; then
    log "Printing contents of file after modification ${outputDir}/${rdfFileNoExtension}/index-en.html "
    cat "${indexHtml}"
  fi

  return 0
}

#
# Replace all "hrefs" that refer to URLs with .../ontology/.. in it to their .../widoco/.. equivalents so that
# everyone can navigate around through all the widoco docs that we generate for each ontology
#
function widocoReplaceOntologyIRIs() {

  local -r outputFolder="$1"

  if [[ ! -f "${outputFolder}/index-en.html" ]] ; then
#    error "index-en.html has not been generated"
#    return 1
      echo "index-en.html has not been generated"
      return 0 
  fi

  #
  # TODO: If we even are going to support multi-lingual widoco output we would need to refer to index-<language>
  #       rather than index-en.html
  #
  for htmlFile in "${outputFolder}"/**/*.html ; do
    logItem "Replacing IRIs in" "$(logFileName "${htmlFile}")"
    ${SED} \
      -i \
      `# replace all ../ontology/.. urls used in hrefs with their ../widoco/.. counterparts` \
      `# note that we leave out href=#<url> because those are not real urls but fragment IDs` \
      -e 's@href="\([^#][^"]*\)/ontology/\([^"]*\)"@href="\1/widoco/\2/index-en.html"@g' \
      `# stich index-en.html at the end` \
      -e 's@//index-en.html@/index-en.html@g' \
      `# replace any visible references to version IRIs` \
      -e "s@title=\"${ontology_tag_root_url}@title=\"${ontology_product_root_url}@g" \
      `# replace all hrefs with versioned IRIs` \
      -e "s@href=\"${product_root_url}@href=\"${tag_root_url}@g" \
      `# remove duplicates` \
      -e "s@${branch_tag}/${branch_tag}@${branch_tag}@g" \
      -e "s@${branch_tag}/${branch_tag}@${branch_tag}@g" \
      `# make all hrefs relative so that we can host this locally via http://localhost` \
      -e "s@<a href=\"https://spec.edmcouncil.org@<a href=\"@g" \
      "${htmlFile}"
  done

  return 0
}

#
# Called by buildVowlIndex() exclusively
#
function buildVowlIndexInvokeTree() {

  local -r title="$1"
  local -r type="$2" # RELEASE or empty
  local -r outputFile="$3"

  logItem "Generating" "$(logFileName "${outputFile}")"

  #
  # KG>Do we need this -I '*Ext'
  # JG>I don't know, PR knows more about this
  #
  ${TREE} \
    -P "*.rdf${type}" \
    -I  "[0-9]*|*Ext|About*|All*|Metadata*|ont-policy.rdf" \
    -T "${title}" \
    --noreport \
    --dirsfirst \
    -H "${tag_root_url:?}" | \
    ${SED} \
      -e "s@${GIT_BRANCH}\/${GIT_TAG_NAME}\/\(/[^/]*/\)@${GIT_BRANCH}\/${GIT_TAG_NAME}/\\U\\1@" \
      -e "s@\(${product_branch_tag:?}/.*\)\.rdf${type}\">@\1/index-en.html\">@" \
      -e "s@href=\"${tag_root_url:?}/@href=\"@g" \
      -e "s@rdf${type}@rdf@g" \
      -e 's@\(.*\).rdf@\1@' \
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
# Called by buildVowlIndex() exclusively
#
function buildVowlIndexInvokeTreeForJson() {

  local -r title="$1"
  local -r type="$2" # RELEASE or empty
  local -r outputFile="$3"

  #
  # JG>Saving original call to tree util (for json output) here
  #
  #${TREE} -J -P '*.rdf' > "${vowlTreeDjson}"

  logItem "Generating" "$(logFileName "${outputFile}")"

  #
  # KG>Do we need this -I '*Ext'
  # JG>I don't know, PR knows more about this
  #
  ${TREE} \
    -P "*.rdf${type}" \
    -I  "[0-9]*|*Ext|About*|All*|Metadata*|ont-policy.rdf" \
    -J \
    --noreport \
    --dirsfirst | \
    ${SED} \
      -e "s@rdf${type}@rdf@g" \
      > "${outputFile}"
}

#
# The vowl "index" of fibo is a list of all the ontology files, in their
# directory structure and link to the vowl documentation.  This is an attempt to automatically produce
# this.
#
function buildVowlIndex () {

  local -r vowlTreeP="${widoco_product_tag_root}/vowltreeProd.html"
  local -r vowlTreeD="${widoco_product_tag_root}/vowltreeDev.html"
  local -r vowlTreePjson="${widoco_product_tag_root}/vowltreeProd.json"
  local -r vowlTreeDjson="${widoco_product_tag_root}/vowltreeDev.json"
  local -r titleP="FIBO Widoco File Directory (Production)"
  local -r titleD="FIBO Widoco File Directory (Development)"

  touch "${widoco_product_tag_root}"/widoco.log
  
  logStep "buildVowlIndex"

  (
    cd "${ontology_product_tag_root}" || return $?

    buildVowlIndexInvokeTree "${titleD}" "" "${vowlTreeD}"

#   log "Printing contents of tree ${vowlTreeD}"
#   contents=$(<${vowlTreeD})
#   echo ${contents}

    #
    # PR>Leaving the logic here in case there are further widoco failures later
    #
#    failedOntologies="XXXXX"
#    IFS=',' read -ra FAILED_ONTOLOGIES <<< "$failedOntologies"
#    for i in "${FAILED_ONTOLOGIES[@]}"; do
#      ${SED} -i "s/<a.*\/$i\/index-en\.html\">\([^<]*\) vowl<\/a>/\1/g" "${vowlTreeD}"
#    done

    local pfiles ; pfiles="$(mktempWithExtension pfiles txt)" || return $?

    ${GREP} -rl 'utl-av[:;.]Release' . > ${pfiles}
    cat ${pfiles} | while read file ; do mv ${file} ${file}RELEASE ; done

    buildVowlIndexInvokeTree "${titleP}" "RELEASE" "${vowlTreeP}"

    #
    # Also create a JSON version of the tree file so that we can later easily add a browsing function to the new
    # SPA (single page application) front end
    #
    buildVowlIndexInvokeTreeForJson "${titleD}" "" "${vowlTreeDjson}"
    buildVowlIndexInvokeTreeForJson "${titleP}" "RELEASE" "${vowlTreePjson}"

    cat ${pfiles} | while read file ; do mv ${file}RELEASE ${file} ; done
    rm ${pfiles}
  )

	return 0
}
