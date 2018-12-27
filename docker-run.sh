#!/usr/bin/env bash
#
# Builds and runs the docker image for the publisher process.
#
# Optionally use "--shell" to get into the container.
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1

export family="${FAMILY:-fibo}"
export FAMILY="${family}"

if [ -f ${SCRIPT_DIR}/publisher/lib/_functions.sh ] ; then
  # shellcheck source=publisher/lib/_functions.sh
  source ${SCRIPT_DIR}/publisher/lib/_functions.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source publisher/lib/_functions.sh || exit $?
fi

#
# Get the directory of your local git clone of your ontologies that we need to use
# as input to the publisher.
#
# Add your own directory to this list with another "elif" statement.
#
# TODO: Make this configurable outside this script
#
function inputDirectory() {
    echo -n "c:/Users/Dean/Documents/${family}"

  return 0
}

#
# Find the "output directory" which is the directory that gets the end results of the build/publish process.
#
function outputDirectory() {
  
#  mkdir -p "c:/Users/Dean/Documents/target" >/dev/null 2>&1
  echo -n "c:/Users/Dean/Documents/target" 
}

function temporaryFilesDirectory() {

#  mkdir -p "c:/Users/Dean/Documents/target" >/dev/null 2>&1
  echo -n "c:/Users/Dean/Documents/dockertemp" 

}

function build() {

  "${SCRIPT_DIR}/docker-build.sh" "$@"
}

function checkCommandLine() {

  #
  # The --shell option allows you to end up in the shell of the publisher container itself
  #
  if [[ "$@" =~ .*--shell($|[[:space:]]) ]] ; then
    run_shell=1
  else
    run_shell=0
  fi

  #
  # The --dev option makes the container use the local publisher directory for its sources rather than copying
  # that into the image.
  #
  if [[ "$@" =~ .*--dev($|[[:space:]]) ]] ; then
    run_dev_mode=1
  else
    run_dev_mode=0
  fi

  #
  # The --clean option wipes out the contents of the target directory before the container starts
  #
  if [[ "$@" =~ .*--clean($|[[:space:]]) ]] ; then
    run_clean=1
  else
    run_clean=0
  fi
}

function run() {

  requireValue family || return $?

  build "$@" || return $?
  checkCommandLine "$@"

  cd "${SCRIPT_DIR}" || return $?

  local inputDirectory ; inputDirectory=$(inputDirectory) || return $?
  local outputDirectory ; outputDirectory=$(outputDirectory) || return $?
  local temporaryFilesDirectory ; temporaryFilesDirectory=$(temporaryFilesDirectory) || return $?

  if ((run_clean)) ; then
    log "Cleaning ${outputDirectory}"
    rm -rf "${outputDirectory:?}/"*
  else
    log "Not cleaning ${outputDirectory}"
  fi

  local -a opts=()

  opts+=('run')
  opts+=('--privileged')
  opts+=('--rm')
  opts+=('--tty')

  logVar family
  log "Mounted:"
  logItem "/input/${family}" "${inputDirectory}"
  opts+=("--mount type=bind,source=${inputDirectory},target=/input/${family},readonly,consistency=cached")
  logItem "/output" "${outputDirectory}"
  opts+=("--mount type=bind,source=${outputDirectory},target=/output,consistency=delegated")
#  logItem "/var/tmp" "${temporaryFilesDirectory}"
#  opts+=("--mount type=bind,source=${temporaryFilesDirectory},target=/var/tmp,consistency=delegated")
  logItem "/tmp" "${temporaryFilesDirectory}/../tmp2"
  opts+=("--mount type=bind,source=${temporaryFilesDirectory}/../tmp2,target=/tmp,consistency=delegated")
  #
  # When running in dev mode we mount the ontology publisher's repo's root directory as well
  #
  if ((run_dev_mode)) ; then
    logItem "/publisher" "${SCRIPT_DIR}/publisher"
    opts+=("--mount type=bind,source=${SCRIPT_DIR}/publisher,target=/publisher,readonly,consistency=cached")
  fi

  if ((run_shell)) ; then
    log "Launching the ontology-publisher container in shell mode."
    log "Type $(bold ./publish.sh) to start the build and $(bold exit) to leave this container."
    log "If you want to run the publication of just one or more \"products\" then"
    log "specify the names of these products after $(bold ./publish.sh), for instance:"
    log ""
    log ""
    log ""
    log ""
    log ""
    log ""
    log "$(bold ./publish.sh ontology vocabulary)"
    log ""
    opts+=('--interactive')
    opts+=('--entrypoint')
    opts+=('/bin/bash')
  else
    log "Launching the container"
  fi

  opts+=('ontology-publisher:latest')

  if ((run_shell)) ; then
    opts+=('-l')
  fi

  set -x
  docker ${opts[@]}
  local rc=$?
  set +x
  return ${rc}
}

run "$@"
exit $?
