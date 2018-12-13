#!/usr/bin/env bash
#
# Build the docker image for the publisher process
#
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1

if [ -f ${SCRIPT_DIR}/publisher/lib/_functions.sh ] ; then
  # shellcheck source=publisher/lib/_functions.sh
  source ${SCRIPT_DIR}/publisher/lib/_functions.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source publisher/lib/_functions.sh || exit $?
fi

function checkCommandLine() {

  #
  # The --dev option makes the container use the local publisher directory for its sources rather than copying
  # that into the image.
  #
  if [[ "$@" =~ .*--dev($|[[:space:]]) ]] ; then
    run_dev_mode=1
  else
    run_dev_mode=0
  fi
}

function dockerFile() {

  if ((run_dev_mode)) ; then
    cat "${SCRIPT_DIR}/Dockerfile" | sed '/skip in dev mode begin/,/skip in dev mode end/ d' > "${SCRIPT_DIR}/Dockerfile.dev"
    echo -n "${SCRIPT_DIR}/Dockerfile.dev"
  else
    echo -n "${SCRIPT_DIR}/Dockerfile"
  fi
}

function build() {

  checkCommandLine "$@"

  cd "${SCRIPT_DIR}" || return $?
  #
  # Build the image and tag it as ontology-publisher:latest
  #
  log "docker build --file $(dockerFile) --tag ontology-publisher:latest"
  if docker build --file $(dockerFile) . --tag ontology-publisher:latest ; then
    log "--------- Finished Building the Docker Image ---------"
    return 0
  fi
  error "Could not build"
  return 1
}

build "$@"
exit $?
