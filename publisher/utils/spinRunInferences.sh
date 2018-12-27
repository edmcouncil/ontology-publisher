#!/usr/bin/env bash
#
# Invoke SPIN to run inferences
#
SCRIPT_DIR="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P)"

if [ -f ${SCRIPT_DIR}/../lib/_functions.sh ] ; then
  source ${SCRIPT_DIR}/../lib/_functions.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source ../lib/_functions.sh || exit $?
fi
if [ -f ${SCRIPT_DIR}/../lib/_globals.sh ] ; then
  source ${SCRIPT_DIR}/../lib/_globals.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source ../lib/_globals.sh || exit $?
fi

function generateLog4jConfig() {

  #
  # Don't overwrite an existing one created by a previous (or parallel) run of this script
  #
  [ -f ${TMPDIR}/jena-log4j.properties ] && return 0

  cat > ${TMPDIR}/jena-log4j.properties << __HERE__
log4j.rootLogger=INFO, stdlog

log4j.appender.stdlog=org.apache.log4j.ConsoleAppender
log4j.appender.stdlog.target=System.err
log4j.appender.stdlog.layout=org.apache.log4j.PatternLayout
log4j.appender.stdlog.layout.ConversionPattern=%d{HH:mm:ss} %-5p %-20c{1} :: %m%n
log4j.appender.stdout.Threshold=INFO

## Execution logging
log4j.logger.org.apache.jena.arq.info=INFO
log4j.logger.org.apache.jena.arq.exec=INFO

## TDB loader
log4j.logger.org.apache.jena.tdb.loader=INFO
## TDB syslog.
log4j.logger.TDB=INFO

## Everything else in Jena
log4j.logger.org.apache.jena.riot=INFO
log4j.logger.org.apache.jena=INFO
log4j.logger.org.apache.jena.util=INFO
log4j.logger.org.openjena=INFO
log4j.logger.org.openjena.riot=INFO
log4j.logger.org.apache.jena.util.FileManager=INFO

##
## FileManager and LocationManager logging, see
## https://jena.apache.org/documentation/notes/file-manager.html
##
log4j.logger.org.apache.jena.util.FileManager=INFO
log4j.logger.org.apache.jena.util.LocatorFile=INFO
log4j.logger.org.apache.jena.util.LocationManager=INFO
log4j.logger.org.apache.jena.riot.adapters.AdapterFileManager=TRACE
log4j.logger.org.apache.jena.riot.system.stream=INFO
log4j.logger.org.apache.jena.riot=INFO
#
__HERE__
}

function spinRunInferences() {

  require family || return $?
  require WORKSPACE || return $?
  require SPIN_VERSION || return $?
  require spec_family_root || return $?

  local -r  inputFile="$1" ; requireParameter inputFile || return $?
  local -r outputFile="$2" ; requireParameter outputFile || return $?
  local rc

  if [ ! -f "${inputFile}" ] ; then
    error "Input file not found, cannot run SPIN: ${inputFile}"
    return 1
  fi

  logItem "spin input"  "$(realpath "${inputFile}")"
  logItem "spin output" "$(realpath "${outputFile}")"

  local -r outputDirectory="$(dirname "${outputFile}")"

  logItem "spin output directory" "${outputDirectory}"

  [ -f "${outputFile}" ] && rm -f "${outputFile}"

  if [ ! -d /usr/share/java/jena/jena-old ] ; then
    error "Could not find jena-old, can't run SPIN"
    return 1
  fi

  local jars="/usr/share/java/spin/spin-${SPIN_VERSION}.jar"
  jars+=":/usr/share/java/spin/src-tools"
  jars+=":/usr/share/java/jena/jena-old/lib/*"

  #
  # Get the location of the generated location-mapping.n3 file and
  # the ont-policy.rdf file by switching the current product to
  # "ontology" to get the right value for tag_root. Then switch
  # it back to whichever product was current.
  #
  local savedProduct="${ontology_publisher_current_product:?}"

  setProduct ontology || return $?

  local -r locationMappingFile="${tag_root:?}/location-mapping.n3"
  local -r ontologyPolicyFile="${tag_root:?}/ont-policy.rdf"

  setProduct "${savedProduct}" || return $?

  cd /output/${family} || return 1

  if [ -f "${locationMappingFile}" ] ; then
    log "Found ${locationMappingFile}"
  else
    error "Could not find ${locationMappingFile}"
  fi
  if [ -f "${ontologyPolicyFile}" ] ; then
    log "Found ${ontologyPolicyFile}"
  else
    error "Could not find ${ontologyPolicyFile}"
  fi

  log "Run SPIN inferences on ${inputFile/${WORKSPACE}/}"
  logItem "Current Directory" "$(pwd)"

  #
  # There's no other way to tell jena where to find the ont-policy.rdf file
  # so we have to copy it into the local directory (and remove it afterwards
  # so that we don't publish it here.
  #
  cp "${locationMappingFile}" "$(pwd)"
  cp "${ontologyPolicyFile}" "$(pwd)"

  java \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    -Dxxx=spin \
    -Xms2g \
    -Xmx2g \
    -Dfile.encoding=UTF-8 \
    -Djava.io.tmpdir="${TMPDIR}" \
    -Dlog4j.configuration="file:${TMPDIR}/jena-log4j.properties" \
    -cp "${jars}" \
    org.topbraid.spin.tools.RunInferences \
    http://example.org/example \
    "${inputFile}" >> "${outputFile}" # 2> "${outputFile}.log"
  rc=$?

  if ((rc > 0)) ; then
    error "Could not run spin on ${inputFile}"
  fi

  return ${rc}
}

function main() {

  initOSBasedTools || return $?
  initWorkspaceVars || return $?
  generateLog4jConfig || return $?
  spinRunInferences "$@"
}

main "$@"
exit $?
