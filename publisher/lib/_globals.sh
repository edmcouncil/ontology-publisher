#!/usr/bin/env bash
#
# Set all the global variables that we need to run the publish
#

#
# For testing - speedy=true leaves out some very slow processing,
# e.g., isDefinedBy, conversations into ttl and jsonld, and nquads
#
# TODO: Make this settable via an environment variable so that we can override
#       this in the Jenkinsfile (so that master for instance will never be built
#       with speedy=true)
#
export speedy=${speedy:-1}
export verbose=${verbose:-1}
export debug=${debug:-1}

#
# The products that we generate the artifacts for with this script
#
# ontology has to come before vocabulary because vocabulary depends on it.
#
export family="${FAMILY:-${family:-fibo}}"
export spec_host="${spec_host:-spec.edmcouncil.org}"
#
# DA>Removed for speedier testing
# JG>It's not really relevant anymore what products are mentioned here
#    since the Jenkinsfile now specifies which particular product it's
#    going to build (in order to be able to run those product builds in
#    parallel).
#
#products="ontology widoco glossary datadictionary vocabulary"
#products="ontology glossary datadictionary vocabulary "
products="ontology widoco glossary"

modules=""
module_directories=""

stardog_vcs=""

if [ -z "${WORKSPACE}" ] && ((RUNNING_IN_DOCKER == 1)) ; then
  export WORKSPACE=/publisher
fi

function checkCommandLine() {

  #
  # The --verbose option switches on verbose logging
  #
  if [[ "$@" =~ .*--verbose($|[[:space:]]) ]] ; then
    verbose=1
  fi

  #
  # The --no-verbose or --silent option switches verbose logging off
  #
  if [[ "$@" =~ .*--no-verbose($|[[:space:]]) || "$@" =~ .*--silent($|[[:space:]]) ]] ; then
    verbose=0
  fi

  #
  # The --speedy option can be used to skip a few time consuming tasks
  #
  if [[ "$@" =~ .*--speedy($|[[:space:]]) ]] ; then
    speedy=1
  fi

  #
  # The --no-speedy option switches speedy mode off
  #
  if [[ "$@" =~ .*--no-speedy($|[[:space:]]) ]] ; then
    speedy=0
  fi
}

checkCommandLine "$@"
logVar verbose
logVar speedy