#!/usr/bin/env bash
#
# Builds and runs the docker image for the publisher process.
#
# Optionally use "--shell" to get into the container.
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1

export ONTPUB_FAMILY="${ONTPUB_FAMILY:-fibo}"
export ONTPUB_SPEC_HOST="${ONTPUB_SPEC_HOST:-spec.edmcouncil.org}"

if [[ -f ${SCRIPT_DIR}/publisher/lib/_functions.sh ]] ; then
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

  # JG>Dean, to make this work from inside your shell-container we need
  # to have a detection here whether we're running inside that container
  # or not. When you're IN the container, we cannot check for the existence
  # of /cygdrive/c/Users/Dean/Documents/${ONTPUB_FAMILY}

  if isRunningInDockerContainer ; then
    #
    # When we're running inside a docker container we cannot test for the existence of
    # the windows directory that's supposed to be the input directory.
    # That shell-container should pass the current user id through somehow. Windows has it in USERNAME env var.
    #
    #
    # JG>Dean and/or Pete can you check if there's an environment variable available when you run this
    #    that contains your user name as RivettPJ or Dean so that we can automate at least part of the
    #    path name below?
    #
    # echo -n "/c/Users/RivettPJ/Documents/FIBO-Development"
      echo -n "/c/Users/Dean/Documents/fibo"
    return 0
  fi

  if [[ -d "${HOME}/Work/${ONTPUB_FAMILY}" ]] ; then # Used by Jacobus
    echo -n "${HOME}/Work/${ONTPUB_FAMILY}"
  elif [[ -d "/c/Users/RivettPJ/Documents/FIBO-Development" ]] ; then
    echo -n "/c/Users/RivettPJ/Documents/FIBO-Development"
  elif [[ -d "${HOME}/${ONTPUB_FAMILY}" ]] ; then
    echo -n "${HOME}/Work/${ONTPUB_FAMILY}"
  elif [[ -d "/cygdrive/c/Users/Dean/Documents/${ONTPUB_FAMILY}" ]] ; then
    echo -n "c:/Users/Dean/Documents/${ONTPUB_FAMILY}"
  else
    error "No ${ONTPUB_FAMILY} root found"
    return 1
  fi

  return 0
}

#
# Find the "output directory" which is the directory that gets the end results of the build/publish process.
#
function outputDirectory() {

  #
  # JG>Dean, same thing here, we need to test whether we're inside your shell container
  # or not. If inside that container, then do not execute the mkdir statement
  #

  if isRunningInDockerContainer ; then
    #
    # When we're running inside a docker container we cannot test for the existence of
    # the windows directory that's supposed to be the output directory.
    # That shell-container should pass the current user id through somehow. Windows has it in USERNAME env var.
    #
    # Dean, the input and output directory should be different from each other
    #
    echo -n "c:/Users/Dean/Documents/${ONTPUB_FAMILY}-output"
    return 0
  fi

  mkdir -p "${SCRIPT_DIR}/../target" >/dev/null 2>&1
  echo -n "$(cd ${SCRIPT_DIR}/../target && pwd -L)"
}

function temporaryFilesDirectory() {

  #
  # JG>Dean, same thing here, we need to test whether we're inside your shell container
  # or not. If inside that container, then do not execute the mkdir statement
  #

  if isRunningInDockerContainer ; then
    #
    # When we're running inside a docker container we cannot test for the existence of
    # the windows directory that's supposed to be the tmp directory.
    # That shell-container should pass the current user id through somehow. Windows has it in USERNAME env var.
    #
    echo -n "c:/Users/Dean/Documents/${ONTPUB_FAMILY}-tmp"
    return 0
  fi

  if ! mkdir -p "${SCRIPT_DIR}/../tmp" >/dev/null 2>&1 ; then
    error "Could not create directory ${SCRIPT_DIR}/../tmp"
  fi

  echo -n "$(cd ${SCRIPT_DIR}/../tmp && pwd -L)"
}

function checkCommandLine() {

  #
  # The --pushimage option publishes the image, after a successful build, to Dockerhub
  #
  if [[ "$*" =~ .*--pushimage($|[[:space:]]) || "$*" =~ .*--push($|[[:space:]]) ]] ; then
    cli_option_pushimage=1
  else
    cli_option_pushimage=0
  fi

  #
  # The --build option builds the image
  #
  if [[ "$*" =~ .*--buildimage($|[[:space:]]) || "$*" =~ .*--build($|[[:space:]]) ]] ; then
    cli_option_buildimage=1
  else
    cli_option_buildimage=0
  fi

  #
  # The --rebuild option builds the image from scratch
  #
  if [[ "$*" =~ .*--rebuildimage($|[[:space:]]) || "$*" =~ .*--rebuild($|[[:space:]]) ]] ; then
    cli_option_buildimage=1
    cli_option_rebuildimage=1
  else
    cli_option_rebuildimage=0
  fi

  #
  # The --run option runs the container
  #
  if [[ "$*" =~ .*--run($|[[:space:]]) ]] ; then
    cli_option_runimage=1
  else
    cli_option_runimage=0
  fi

  #
  # The --shell option allows you to end up in the shell of the publisher container itself
  #
  if [[ "$*" =~ .*--shell($|[[:space:]]) ]] ; then
    cli_option_buildimage=1
    cli_option_runimage=1
    cli_option_shell=1
  else
    cli_option_shell=0
  fi

  #
  # The --dev option makes the container use the local publisher directory for its sources rather than copying
  # that into the image.
  #
  if [[ "$*" =~ .*--dev($|[[:space:]]) ]] ; then
    cli_option_dev_mode=1
  else
    cli_option_dev_mode=0
  fi

  #
  # The --clean option wipes out the contents of the target directory before the container starts
  #
  if [[ "$*" =~ .*--clean($|[[:space:]]) ]] ; then
    cli_option_clean=1
  else
    cli_option_clean=0
  fi

  #
  # The --dark option forces dark mode for all the colors being used.
  #
  if [[ "$*" =~ .*--dark($|[[:space:]]) ]] ; then
    cli_option_dark=1
  else
    cli_option_dark=$(getIsDarkMode ; echo $?)
  fi

  #
  # The --verbose option shows more logging
  #
  if [[ "$*" =~ .*--verbose($|[[:space:]]) ]] ; then
    cli_option_verbose=1
  else
    cli_option_verbose=0
  fi

  if ((cli_option_dev_mode == 1 && cli_option_pushimage == 1)) ; then
    error "Cannot push a dev-mode image to docker hub, the publisher code has to be copied into the image"
    return 1
  fi

  if ((cli_option_verbose)) ; then
    logBoolean cli_option_buildimage
    logBoolean cli_option_rebuildimage
    logBoolean cli_option_runimage
    logBoolean cli_option_pushimage
    logBoolean cli_option_shell
    logBoolean cli_option_clean
    logBoolean cli_option_dark
    logBoolean cli_option_dev_mode
  fi

  return 0
}

function dockerFile() {

  if ((cli_option_dev_mode)) ; then
    cat "${SCRIPT_DIR}/Dockerfile" | sed '/skip in dev mode begin/,/skip in dev mode end/ d' > "${SCRIPT_DIR}/Dockerfile.dev"
    echo -n "${SCRIPT_DIR}/Dockerfile.dev"
  else
    echo -n "${SCRIPT_DIR}/Dockerfile"
  fi
}

function containerName() {

  echo -n "ontology-publisher"

  if ((cli_option_dev_mode)) ; then
    #
    # Just to make sure that the dev-mode version of the image is not being pushed to Docker Hub because it
    # can't run on its own, it doesn't contain the /publisher directory
    #
    echo -n "-dev"
  fi
}

function idOfRunningContainer() {

  local -r containerName="$(containerName)"

  docker ps -a --no-trunc --filter name=^/${containerName}$ --quiet
}

function isContainerRunning() {

  local -r id="$(idOfRunningContainer)"

  [[ -n "${id}" ]]
}

function buildImage() {

  ((cli_option_buildimage)) || return 0

  local -r containerName="$(containerName)"

  if isContainerRunning ; then
    warning "Container ${containerName} is running so we skip the build"
    return 0
  fi

  cd "${SCRIPT_DIR}" || return $?

  local -a opts=()

  opts+=('build')
  ((cli_option_rebuildimage)) && opts+=('--no-cache')
  opts+=('--build-arg')
  opts+=("ONTPUB_FAMILY=${ONTPUB_FAMILY}")
  opts+=('--build-arg')
  opts+=("ONTPUB_SPEC_HOST=${ONTPUB_SPEC_HOST}")
  opts+=('--build-arg')
  opts+=("ONTPUB_IS_DARK_MODE=${cli_option_dark}")
  opts+=('--label')
  opts+=('org.edmcouncil.ontology-publisher.version="0.0.1"')
  opts+=('--label')
  opts+=("org.edmcouncil.ontology-publisher.release-date="$(date "+%Y-%m-%d")"")
  opts+=('--tag')
  opts+=("edmcouncil/${containerName}:latest")
  opts+=('--file')
  opts+=("$(dockerFile) .")

  #
  # Build the image and tag it as ontology-publisher:latest
  #
  log "docker ${opts[@]}"
  if docker ${opts[@]} ; then
    log "--------- Finished Building the Docker Image ---------"
    return 0
  fi

  error "Could not build the image"
  return 1
}

function pushImage() {

  ((cli_option_pushimage == 0)) && return 0

  log "docker push edmcouncil/ontology-publisher:latest"

  docker push edmcouncil/ontology-publisher:latest
}

function run() {

  ((cli_option_runimage == 0)) && return 0

  if isContainerRunning ; then
    return 0
  fi

  requireValue ONTPUB_FAMILY || return $?

  cd "${SCRIPT_DIR}" || return $?

  local inputDirectory ; inputDirectory=$(inputDirectory) || return $?
  local outputDirectory ; outputDirectory=$(outputDirectory) || return $?
  local temporaryFilesDirectory ; temporaryFilesDirectory=$(temporaryFilesDirectory) || return $?
  local containerName="ontology-publisher"

  if ((cli_option_dev_mode)) ; then
    #
    # Just to make sure that the dev-mode version of the image is not being pushed to Docker Hub because it
    # can't run on its own, it doesn't contain the /publisher directory
    #
    containerName+='-dev'
  fi

  if ((cli_option_clean)) ; then
    log "Cleaning ${outputDirectory}"
    rm -rf "${outputDirectory:?}/"*
    log "Cleaning ${temporaryFilesDirectory}"
    rm -rf "${temporaryFilesDirectory:?}/"*
  else
    log "Not cleaning ${outputDirectory}"
  fi

  local -a opts=()

  opts+=('run')
  opts+=('--rm')
  opts+=('--tty')
# opts+=('--network')
# opts+=('none')
  opts+=('--name')
  opts+=("${containerName}")
  #
  # Remove the --read-only option if you want to experiment with adding new tools to the running container.
  # The --read-only flag is set by default (by this script) to protect the image from being overwritten by anything
  # that runs inside the container itself.
  #
  opts+=('--read-only')
  opts+=('--env')
  opts+=("ONTPUB_IS_DARK_MODE=${cli_option_dark}")
  opts+=('--env')
  opts+=("ONTPUB_FAMILY=${ONTPUB_FAMILY}")
  opts+=('--env')
  opts+=("ONTPUB_SPEC_HOST=${ONTPUB_SPEC_HOST}")

  logVar ONTPUB_FAMILY
  log "Mounted:"
  logItem "/input/${ONTPUB_FAMILY}" "${inputDirectory}"
  opts+=("--mount type=bind,source=${inputDirectory},target=/input/${ONTPUB_FAMILY},readonly,consistency=cached")
  logItem "/output" "${outputDirectory}"
  opts+=("--mount type=bind,source=${outputDirectory},target=/output,consistency=delegated")
#  logItem "/var/tmp" "${temporaryFilesDirectory}"
#  opts+=("--mount type=bind,source=${temporaryFilesDirectory},target=/var/tmp,consistency=delegated")

  #
  # When running in dev mode we mount the ontology publisher's repo's root directory as well
  #
  if ((cli_option_dev_mode)) ; then
    logItem "/publisher" "${SCRIPT_DIR}/publisher"
    opts+=("--mount type=bind,source=${SCRIPT_DIR}/publisher,target=/publisher,readonly,consistency=cached")
  fi

  if ((cli_option_shell)) ; then
    log "Launching the ${containerName} container in shell mode."
    logShellWelcome
    opts+=('--interactive')
    opts+=('--tty')
    opts+=('--entrypoint')
    opts+=('/bin/bash')
  else
    log "Launching the container"
  fi

  opts+=("edmcouncil/${containerName}:latest")

  if ((cli_option_shell)) ; then
    opts+=('-l')
  fi

  log "docker ${opts[@]}"
  docker ${opts[@]}
  local -r rc=$?

  return ${rc}
}

function logShellWelcome() {

  log "Type $(bold ./publish.sh) to start the build and $(bold exit) to leave this container."
  log ""
  log "If you want to run the publication of just one or more \"products\" then"
  log "specify the names of these products after $(bold ./publish.sh), for instance:"
  log ""
  log ""
  log ""
  log "$(bold ./publish.sh ontology vocabulary)"
  log ""
}

#
# Connect to the running container with a bash login shell
#
function shell() {

  if ! isContainerRunning ; then
    return 0
  fi

  local -r id="$(idOfRunningContainer)"

  logShellWelcome
  docker exec --interactive --tty ${id} bash --login
}

function main() {

  checkCommandLine "$@" || return $?
  buildImage || return $?
  pushImage || return $?
  run || return $?
  shell
}

main $@
exit $?
