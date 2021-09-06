#!/usr/bin/env bash
#
# Set all the global variables that we need to run the publish
#

# shellcheck source=_functions.sh
false && source _functions.sh

#
# The products that we generate the artifacts for with this script
#
# ontology has to come before vocabulary because vocabulary depends on it.
#
products="ontology datadictionary vocabulary fibopedia"

modules=""
module_directories=""

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

function checkCommandLine() {

  #
  # The --verbose option switches on verbose logging
  #
  if [[ "$@" =~ .*--verbose($|[[:space:]]) ]] ; then
    export verbose=$(true ; echo $?)
  fi

  #
  # The --no-verbose or --silent option switches verbose logging off
  #
  if [[ "$@" =~ .*--no-verbose($|[[:space:]]) || "$@" =~ .*--silent($|[[:space:]]) ]] ; then
    export verbose=$(false ; echo $?)
  fi

  #
  # The --speedy option can be used to skip a few time consuming tasks
  #
  if [[ "$@" =~ .*--speedy($|[[:space:]]) ]] ; then
    export speedy=$(true ; echo $?)
  fi

  #
  # The --no-speedy option switches speedy mode off
  #
  if [[ "$@" =~ .*--no-speedy($|[[:space:]]) ]] ; then
    export speedy=$(false ; echo $?)
  fi

  #
  # The --debug option can be used to enable debug logging etc
  #
  if [[ "$@" =~ .*--debug($|[[:space:]]) ]] ; then
    export debug=$(true ; echo $?)
  fi
}

checkCommandLine "$@"
logBoolean verbose
logBoolean speedy
logBoolean debug