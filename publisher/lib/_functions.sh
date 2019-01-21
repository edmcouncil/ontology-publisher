#!/usr/bin/env bash
#
# _functions.sh defines a list of generic functions that can be used by any of the
# other scripts in this directory (or its subdirectories).
#

export GREP=grep

#
# Generic function that returns 1 if the variable with the given name does not exist (as a local or global Bash variable or
# as an environment variable)
#
function variableExists() {

  local variableName="$1"

#  if (set -u; : $variableName) 2> /dev/null ; then
#    return 1
#  fi
#  return 0

  export 2>&1 | ${GREP} -q "declare -x ${variableName}=" && return 0
  declare 2>&1 | ${GREP} -q "^${variableName}=" && return 0

  return 1
}

#
# Generic function that can be used to test for the existence of a given variable
#
function require() {

  local variableName="$1"

  variableExists ${variableName} && return 0

  set -- $(caller 0)

  errorNoSource "The $(sourceLine $@) requires ${variableName}"

  return 1
}

#
# Generic function that can be used to test for the existence of a given variable and whether it has a value other
# than an empty string.
#
function requireValue() {

  local variableName="$1"

  if ! variableExists ${variableName} ; then

    set -- $(caller 0)
    error "The $(sourceLine $@) requires ${variableName}"
    return 1
  fi

  local variableValue="${!variableName}"

  [ -n "${variableValue}" ] && return 0

  set -- $(caller 0)

  errorNoSource "The $(sourceLine $@) requires a value in variable ${variableName}"

  exit 1
}

#
# Generic function that can be used to test for the existence of a given variable and whether it has a value other
# than an empty string.
#
function requireParameter() {

  local variableName="$1"

  if ! variableExists ${variableName} ; then

    set -- $(caller 1)

    case $2 in
      assert*) # see test-framework.sh
        set -- $(caller 2)
        errorNoSource "The $(sourceLine $@) requires ${variableName}"
        ;;
      *)
        errorNoSource "The $(sourceLine $@) requires ${variableName}"
        ;;
    esac
    errorNoSource "The $(sourceLine $@) requires ${variableName}"
    return 1
  fi

  local variableValue="${!variableName}"

  [ -n "${variableValue}" ] && return 0

  set -- $(caller 1)
  case $2 in
    assert*) # see test-framework.sh
      set -- $(caller 2)
      errorNoSource "The $(sourceLine $@) requires a value for parameter ${variableName}"
      ;;
    *)
      errorNoSource "The $(sourceLine $@) requires a value for parameter ${variableName}"
      ;;
  esac
  exit 1
}

function isMacOSX() {

  test "$(uname -s)" == "Darwin"
}

#
# Create a temporary file with a given file extension.
#
function mktempWithExtension() {

  local -r name="$1"
  local -r extension="$2"

  local tempName

  (
    if isMacOSX ; then
      tempName="$(mktemp -t "${name}")" || return $?
      local -r newName="${tempName}.${extension}"

      mv -f "${tempName}" "${tempName}.${extension}" || return $?

      echo -n "${newName}"
      return 0
    fi

    tempName="$(mktemp --quiet --suffix=".${extension}" -t "${name}.XXXXXX")" || return $?

    echo -n "${tempName}"
  )
  if [ $? -ne 0 ] ; then
    error "Could not create temporary file ${name}.XXXX.${extension}"
    return 1
  fi

  return 0
}

function printfLog() {

  printf -- "$*" >&2
}

function log() {

  if getIsDarkMode ; then
    lightGreen "$@" >&2
  else
    blue "$@" >&2
  fi
}

function logRule() {

  echo $(printf '=%.0s' {1..40}) $(bold "$@") >&2
}

function logItem() {

  local -r item="$1"
  shift

  if getIsDarkMode ; then
    # lightgreen
    printf -- ' - %-25s : [\e[92m%s\e[0m]\n' "${item}" "$*" >&2
  else
    # blue
    printf -- ' - %-25s : [\e[34m%s\e[0m]\n' "${item}" "$*" >&2
  fi
}

function logVar() {

  logItem "$1" "${!1}"
}

function logBoolean() {

  local -r value="${!1}"

  if ((value)) ; then
    logItem "$1" "true"
    return 0
  fi

  logItem "$1" "false"
  return 1
}

function logValueColor() {

  if getIsDarkMode ; then
    # lightgreen
    printf -- '\e[92m'
  else
    # blue
    printf -- '\e[34m'
  fi
}

function logDir() {

  local -r item="$1"
  local -r directory="${!1}"
  local -r valueColor="$(logValueColor)"

  if [[ -d "${directory}" ]] ; then
    if [[ "$(cd "${directory}" && ls -A)" ]] ; then
      printf -- ' - %-25s : [%b%s\e[0m] (exists)\n' "${item}" "${valueColor}" "$(logFileName "${directory}")" >&2
    else
      printf -- ' - %-25s : [%b%s\e[0m] (is empty)\n' "${item}" "${valueColor}" "$(logFileName "${directory}")" >&2
    fi
    return 0
  fi

  printf -- ' - %-25s : [%b%s\e[0m] (does not exist)\n' "${item}" "${valueColor}" "$(logFileName "${directory}")" >&2
  return 1
}

#
# Log each line of the input stream.
#
function pipelog() {

  while IFS= read -r line; do
    log "${line}"
  done

  return 0
}

function warning() {

  local line="$*"

  if getIsDarkMode ; then
    # light red
    printf "WARNING: \\033[38;5;208m${line}\e[0m\n" >&2
  else
    # red
    printf "WARNING: \e[31m${line}\e[0m\n" >&2
  fi
}

function verbose() {

  ((verbose)) && log "$*"
}

function debug() {

  ((debug)) || return 0

  local args="$@"

  local n=0
  local prefix=""
  while caller $((n++)) >/dev/null 2>&1; do prefix="${prefix}-" ; done;
  prefix="${prefix:2}"

  lightGrey "DEBUG:                    -${prefix}$@" >&2
}

function sourceLine() {

  local -r lineNumber="$1"
  local -r functionName="$2"
  local -r sourceFile="$(sourceFile $3)"
  local -r baseSourceName="$(basename "${sourceFile}")"

  printf "function %s() at .(%s:%d)" "${functionName}" "${baseSourceName}" "${lineNumber}"
}

function error() {

  if ((builder_no_error_prefix)) ; then
    log "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    echo "$(date "+%Y-%m-%d %H:%M:%S.%3N") ERROR: $@" >&2
  else
    local line="$*"
    # shellcheck disable=SC2046
    set -- $(caller 0)
    if ! printf "ERROR: in $(sourceLine "$@"): \\033[38;5;208m${line}\e[0m\n" >&2 ; then
      echo "ERROR: Could not show error: $* ${line}" >&2
    fi
  fi

  return 1
}

function errorNoSource() {

  if ((builder_no_error_prefix)) ; then
    log "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    error "$@"
  else
    local line="$*"
    set -- $(caller 0)
    printf "ERROR: \\033[38;5;208m${line}\e[0m\n" >&2
  fi

  return 1
}

function errorInCaller() {

  if ((builder_no_error_prefix)) ; then
    log "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    echo "$(date "+%Y-%m-%d %H:%M:%S.%3N") ERROR: $@" >&2
  else
    local line="$*"
    line="${line//[0m;/[0;208m}"
    set -- $(caller 1)
    printf "ERROR: in $(sourceLine $@): \\033[38;5;208m${line}\e[0m\n" >&2
  fi

  return 1
}

function errorInCallerOfCaller() {

  if ((builder_no_error_prefix)) ; then
    log "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    echo "$(date "+%Y-%m-%d %H:%M:%S.%3N") ERROR: $@" >&2
  else
    local line="$*"
    set -- $(caller 2)
    printf "ERROR: in $(sourceLine $@): \\033[38;5;208m${line}\e[0m\n" >&2
  fi

  return 1
}

function printfError() {

  if ((builder_no_error_prefix)) ; then
    printfLog "$*"
    return 1
  fi

  if ((builder_running_inside_container)) ; then
    local -r timestamp="$(date "+%Y-%m-%d %H:%M:%S.%3N")"
    local -r formatString="%s ERROR: $1"
    shift
    printf -- "${formatString}" "$@" >&2
  else
    local formatString="ERROR: %s: \\033[38;5;208m%s\e[0m $1"
    shift
    local line="$*"
    # shellcheck disable=SC2046
    set -- $(caller 0)
    printf -- "${formatString}" "$(sourceLine "$@")" ${line} >&2
  fi

  return 1
}

#
# Red is for error messages in light mode
#
function red() {

  printf "\e[31m%b\e[0m\n" "$*"
}

#
# Lightred is for error messages in dark mode
#
function lightRed() {

  printf "\\033[38;5;208m%b\e[0m\n" "$*"
}

#
# Blue is for technical but important messages in light mode
#
function blue() {

  printf "\e[34m%b\e[0m\n" "$*"
}

#
# LightGreen is for technical but important messages in dark mode
#
function lightGreen() {

  printf "\e[92m%b\e[0m\n" "$*"
}

#
# Bold is for emphasis
#
function bold() {

  printf "\e[1m$*\e[0m\n"
}

#
# Lightgrey is for debug/trace type of logging that is usually to be ignored
#
function lightGrey() {

  printf "\e[37m$*\e[0m\n"
}

#
# Log the given file with jq (pretty plus coloring) and if it's not valid JSON say so and dump file on the log
#
function logjson() {

  local file="$1"

  if [ ! -f "${file}" ] ; then
    warning "${file} does not exist"
    return 0
  fi

  if isJsonFile "${file}" ; then
    ${JQ} . "${file}" >&2 # pipelog strips ANSI colors
    return 0
  fi

  log "${file} is not valid JSON:"
  cat "${file}" | pipelog
  log "-----"

  return 1
}

#
# Return true (0) if the given file is a JSON file.
#
function isJsonFile() {

  local file="$1"

  [ -f "${file}" ] || return 1

  ${JQ} . "$1" >/dev/null 2>&1
}

function sourceFile() {

  local sourceFile="$1"
  #
  # Strip the Jenkins workspace directory from the source file name if it's in there
  #
  sourceFile="${sourceFile/${WORKSPACE}/.}"
  #
  # Strip the current directory from the source file name if it's in there
  #
  sourceFile="${sourceFile/$(pwd)/.}"

  printf "${sourceFile}"
}

#
# Use this function to show any file or directory name, it shortens it drastically, especially when running
# in a Jenkins job context where the WORKSPACE path sits in front of all directory and file names.
#
function logFileName() {

  local -r name0="$1"

  if [ -n "${WORKSPACE}" ] ; then
    local -r name1="${name0/${TMPDIR}/<ws>/tmp}"
    local -r name2="${name1/${OUTPUT}/<ws>/output}"
    local -r name3="${name2/${INPUT}/<ws>/input}"
    local -r name4="${name3/${WORKSPACE}/<ws>}"
    echo -n "${name4}"
  else
    local -r name1="${name0/${TMPDIR}/<tmp>}"
    local -r name2="${name1/${OUTPUT}/<output>}"
    local -r name3="${name2/${INPUT}/<input>}"
    echo -n "${name3}"
  fi
}

#
# mktemp does not replace the XXX with a random number if it's not at the end of the string,
# so add the .ttl extension after the tmp files have been created.
#
function createTempFile() {

  local prefix="$1"
  local extension="$2"
  local tmpfile=$(mktemp ${TMPDIR}/${prefix}.XXXXXX)

  mv "${tmpfile}" "${tmpfile}.${extension}"

  printf "${tmpfile}.${extension}"
}

#
# Only call once at the top of the root process
#
function initRootProcess() {

  #
  # TMPDIR
  #
  if [ -z "${TMPDIR}" ] ; then
    error "Missing TMPDIR"
    return 1
  fi
  rm -rf "${TMPDIR:?}/*" >/dev/null 2>&1
}

#
# Initialize (the locations of) the tools that are supposed to be installed at the OS level
#
function initOSBasedTools() {

  local bashMajorVersion="${BASH_VERSINFO:-0}"

  if ((bashMajorVersion != 4)) ; then
    error "We need to run this with Bash 4, not version: ${BASH_VERSINFO:?}"
    if [ "$(uname -s)" == "Darwin" ] ; then
      log "Run 'brew install bash' to get this installed"
      return 1
    fi
  fi
  #
  # The command below is only available in Bash 4
  #
  shopt -s globstar

  #export | sort

  #
  # TAR
  #
  export TAR=tar

  #
  # GREP
  #
  export GREP=grep
  export GREP_OPTIONS=

  #
  # FIND
  #
  export FIND=find

  #
  # SED
  #
  export SED=sed

  #
  # CP
  #
  export CP=cp

  #
  # TREE
  #
  export TREE=tree

  #
  # JQ
  #
  # JQ is used to read/edit JSON files.
  #
  # Install on linux with "yum install jq".
  # Install on Mac OS X with "brew install jq".
  #
  export JQ=jq

  if which jq >/dev/null 2>&1 ; then
    export JQ=$(which jq)
  else
    error "jq not found"
    return 1
  fi

  #
  # Python 3
  #
  export PYTHON3=python3

  if which python3 >/dev/null 2>&1 ; then
    export PYTHON3=$(which python3)
  elif which python3.6 >/dev/null 2>&1 ; then
    export PYTHON3=$(which python3.6)
  else
    error "python3 not found"
    return 1
  fi

  return 0
}

#
# Initialize the (locations of) the tools that are installed via the fibo-infra repo
#
function initRepoBasedTools() {

  #
  # We should install Jena on the Jenkins server and not have it in the git-repo, takes up too much space for each
  # release of Jena
  #
  if [ ! -d /usr/share/java/jena/latest ] ; then
    error "Could not find Jena"
    return 1
  fi
  JENAROOT="$(cd /usr/share/java/jena/latest && pwd -L)" ; export JENAROOT

  export JENA_BIN="${JENAROOT}/bin"
  export JENA_ARQ="${JENA_BIN}/arq"
  export JENA_RIOT="${JENA_BIN}/riot"

  JENA3_JARS="."

  while read jar ; do
    JENA3_JARS+=":${jar}"
  done < <(find "${JENAROOT}/lib/" -name '*.jar')

  export JENA3_JARS

  if [ ! -f "${JENA_ARQ}" ] ; then
    error "${JENA_ARQ} not found"
    return 1
  fi

  return 0
}

function initWorkspaceVars() {

  require INPUT || return $?
  require OUTPUT || return $?
  require ONTPUB_FAMILY || return $?
  require ONTPUB_SPEC_HOST || return $?

  #
  # We use logVar here and not logDir because we really want to show the actual WORKSPACE directory
  # and not the shorthand version of it (which is <ws>)
  #
  logVar WORKSPACE

  if [ -n "${WORKSPACE}" ] && [ -d "${WORKSPACE}/input" ] ; then
    INPUT="${WORKSPACE}/input"
  else
    INPUT="${INPUT:?}"
  fi
  export INPUT

  ((verbose)) && logDir INPUT

  if [ -n "${WORKSPACE}" ] ; then
    OUTPUT="${WORKSPACE}/output"
    mkdir -p "${OUTPUT}" || return $?
  else
    OUTPUT="${OUTPUT:?}"
  fi
  export OUTPUT

  ((verbose)) && logDir OUTPUT

  #
  # TMPDIR
  #
  # If we're running in Jenkins, the environment variable WORKSPACE should be there
  # and the tmp directory is assumed to be there..
  #
  if [ -n "${WORKSPACE}" ] ; then
    TMPDIR="${WORKSPACE}/tmp"
    mkdir -p "${TMPDIR}" || return $?
  else
    TMPDIR="${TMPDIR:?}"
  fi
  export TMPDIR

  ((verbose)) && logDir TMPDIR

  #
  # source_family_root: the root directory of the ${ONTPUB_FAMILY} repo
  #
  export source_family_root="${INPUT:?}/${ONTPUB_FAMILY:?}"

  #
  # Add your own directory locations above if you will
  #
  if [ ! -d "${source_family_root}" ] ; then
    error "source_family_root directory not found (${source_family_root})"
    return 1
  fi
  ((verbose)) && logDir source_family_root

  export spec_root="${OUTPUT:?}"
  export spec_family_root="${spec_root}/${ONTPUB_FAMILY:?}"

  mkdir -p "${spec_family_root}" >/dev/null 2>&1

  ((verbose)) && logDir spec_family_root

  export product_root=""
  export branch_root=""
  export tag_root=""
  export product_branch_tag=""
  #
  # Ontology root is required for other products like widoco
  #
  export ontology_product_tag_root=""
  #
  # TODO: Make URL configurable
  #
  export spec_root_url="https://${ONTPUB_SPEC_HOST}"
  export spec_family_root_url="${spec_root_url}/${ONTPUB_FAMILY}"
  export product_root_url=""
  export branch_root_url=""
  export tag_root_url=""

  return 0
}

#
# Since we have to deal with multiple products (ontology, vocabulary etc) we need to be able to switch back
# and forth, call this function whenever you generate something for another product. The git branch and tag name
# always remain the same though.
#
export ontology_publisher_current_product="${ontology_publisher_current_product}"
#
function setProduct() {

  export ontology_publisher_current_product="$1"

  require GIT_BRANCH || return $?
  require GIT_TAG_NAME || return $?
  require spec_family_root || return $?

  ((verbose)) && logItem "spec_family_root" "$(logFileName "${spec_family_root}")"

  export product_root="${spec_family_root}/${ontology_publisher_current_product}"
  export product_root_url="${spec_family_root_url}/${ontology_publisher_current_product}"

  if [ ! -d "${product_root}" ] ; then
    mkdir -p "${product_root}" || return $?
  fi

  ((verbose)) && logItem "product_root" "$(logFileName "${product_root}")"

  if [ "${GIT_BRANCH}" == "head" ] ; then
    error "Git repository not checked out to a local branch, GIT_BRANCH = head which is wrong"
    return 1
  fi

  export branch_root="${product_root}/${GIT_BRANCH}"
  export branch_root_url="${product_root_url}/${GIT_BRANCH}"

  if [ ! -d "${branch_root}" ] ; then
    mkdir -p "${branch_root}" || return $?
  fi

  ((verbose)) && logItem "branch_root" "$(logFileName "${branch_root}")"

  export tag_root="${branch_root}/${GIT_TAG_NAME}"
  export tag_root_url="${branch_root_url}/${GIT_TAG_NAME}"

  if [ ! -d "${tag_root}" ] ; then
    mkdir -p "${tag_root}" || return $?
  fi

  ((verbose)) && logItem "tag_root" "$(logFileName "${tag_root}")"

  export product_branch_tag="${ontology_publisher_current_product}/${GIT_BRANCH}/${GIT_TAG_NAME}"
  export family_product_branch_tag="${ONTPUB_FAMILY}/${product_branch_tag}"

  return 0
}

function initGitVars() {

  (
    cd "${source_family_root}" || return $?
    log "Git status:"
    git status 2>&1 | pipelog
    local -r git_status_rc=$?
    logVar git_status_rc
    return ${git_status_rc}
  ) || return $?

  if [ -z "${GIT_COMMIT}" ] ; then
    export GIT_COMMIT="$(cd ${source_family_root} && git rev-parse --short HEAD)"
    ((verbose)) && logVar GIT_COMMIT
  fi

  if [ -z "${GIT_COMMENT}" ] ; then
    export GIT_COMMENT=$(cd ${source_family_root} && git log --format=%B -n 1 ${GIT_COMMIT} | ${GREP} -v "^$")
    ((verbose)) && logVar GIT_COMMENT
  fi

  if [ -z "${GIT_AUTHOR}" ] ; then
    export GIT_AUTHOR=$(cd ${source_family_root} && git show -s --pretty=%an)
    ((verbose)) && logVar GIT_AUTHOR
  fi

  #
  # Get the git branch name to be used as directory names and URL fragments and make it
  # all lower case
  #
  # Note that we always do the subsequent replacements on the GIT_BRANCH value since Jenkins
  # might have specified the value for GIT_BRANCH which might need to be corrected.
  #
  if [ -z "${GIT_BRANCH}" ] ; then
    GIT_BRANCH=$(cd ${source_family_root} && git rev-parse --abbrev-ref HEAD | tr '[:upper:]' '[:lower:]') ; export GIT_BRANCH
  fi
  #
  # Replace all slashes in a branch name with dashes so that we don't mess up the URLs for the ontologies
  #
  export GIT_BRANCH="${GIT_BRANCH//\//-}"
  #
  # Strip the "heads-tags-" prefix from the Branch name if its in there.
  #
  if [[ "${GIT_BRANCH}" =~ ^heads-tags-(.*)$ ]] ; then
    GIT_BRANCH="${BASH_REMATCH[0]}" ; export GIT_BRANCH
  fi
  ((verbose)) && logVar GIT_BRANCH

  if [ "${GIT_BRANCH}" == "" ] ; then
    error "No GIT_BRANCH defined, cannot work without that"
    return 1
  fi

  #
  # If the current commit has a tag associated to it then the Git Tag Message Plugin in Jenkins will
  # initialize the GIT_TAG_NAME variable with that tag. Otherwise set it to "latest"
  #
  # See https://wiki.jenkins-ci.org/display/JENKINS/Git+Tag+Message+Plugin
  #
  if [ "${GIT_TAG_NAME}" == "latest" ] ; then
    unset GIT_TAG_NAME
  fi
  if [ -z "${GIT_TAG_NAME}" ] ; then
    GIT_TAG_NAME="$(cd ${source_family_root} ; echo $(git describe --contains --exact-match 2>/dev/null))"
    GIT_TAG_NAME="${GIT_TAG_NAME%^*}" # Strip the suffix
  fi
  export GIT_TAG_NAME="${GIT_TAG_NAME:-${GIT_BRANCH}_latest}"
  #
  # If the tag name includes an underscore then assume it's ok, leave it alone since the next step is to then
  # treat the part before the underscore as the branch name (see below).
  # If the tag name does NOT include an underscore then put the branch name in front of it (separated with an
  # underscore) so that the further processing down below will not fail.
  #
  if [[ ${GIT_TAG_NAME} =~ ^.+_.+$ ]] ; then
    :
  else
    export GIT_TAG_NAME="${GIT_BRANCH}_${GIT_TAG_NAME}"
    log "Added branch as prefix to the tag: GIT_TAG_NAME=${GIT_TAG_NAME}"
  fi
  ((verbose)) && logVar GIT_TAG_NAME
  #
  # So, if this tag has an underscore in it, it is assumed to be a tag that we should treat as a version, which
  # should be reflected in the URLs of all published artifacts.
  # The first part is supposed to be the branch name onto which the tag was set. The second part is the actual
  # version string, which is supposed to be in the following format:
  #
  # <year>Q<quarter>[S<sequence>]
  #
  # Such as 2017Q1 or 2018Q2S2 (sequence 0 is assumed to be the first delivery that quarter, where we leave out "Q0")
  #
  # Any other version string is accepted too but should not be made on the master branch.
  #
  if [[ "${GIT_TAG_NAME}" =~ ^(.*)_(.*)$ ]] ; then
    tagBranchSection="${BASH_REMATCH[1]}"
    tagVersionSection="${BASH_REMATCH[2]}"

    if [ -n "${tagBranchSection}" ] ; then
      tagBranchSection=$(echo ${tagBranchSection} | tr '[:upper:]' '[:lower:]')
      logItem "Branch in git tag" "${tagBranchSection}"
      export GIT_BRANCH="${tagBranchSection}"
    fi
    if [ -n "${tagVersionSection}" ] ; then
      logItem "Version in git tag" "${tagVersionSection}"
      export GIT_TAG_NAME="${tagVersionSection}"
    fi
  fi

  #
  # Set default product
  #
  setProduct ontology

  return 0
}

function initJiraVars() {

  JIRA_ISSUE="$(echo ${GIT_COMMENT} | rev | ${GREP} -oP '\d+-[A-Z0-9]+(?!-?[a-zA-Z]{1,10})' | rev | sort -u)" ; export JIRA_ISSUE

  return 0
}

function stripQuotes() {

  local temp="$*"

  case "${temp}" in
    *[!\ ]*)
      temp="${temp%\"}"
      temp="${temp#\"}"
      echo -n "$temp"
      ;;
    *)
      echo -n ""
      ;;
  esac
}

function stripQuotes_test_0003_001() {

  test "$(stripQuotes "\" \"")" == "" || return $?
  test "$(stripQuotes "\"abc\"")" == "abc" || return $?
  test "$(stripQuotes "\"abc \"def\"\"")" == "abc \"def\"" || return $?

  return 0
}

#
# See https://tex.stackexchange.com/a/34586
#
function escapeLaTex() {

  local line="$*"

  line="${line//\\/\\\\textbackslash }"

  line="${line//%/\\%}"
  line="${line//\$/\\$}"
  line="${line//#/\\#}"
  line="${line//_/\\_}"
  line="${line//\{/\\\{}"
  line="${line//\}/\\\}}"
  line="${line//&/{\\&\}}"

  line="${line//\~/\\\\textasciitilde }"
  line="${line//^/\\\\textasciicircum }"

  echo -n "${line}"
}

function escapeLaTex_test_002_0001() {

  local -r result="$(escapeLaTex "whatever_dude\what %is% #metoo in {this} ~day & ^age")"

  echo "[${result}]"

  test "${result}" == "whatever\_dude\\textbackslash what \%is\% \#metoo in \{this\} \\textasciitilde day {\&} \\textasciicircum age"
}
#escapeLaTex_test_002_0001
#exit $?

function escapeLaTexLabel() {

  local line="$*"

  echo -n "${line//[_&%\$#\{\}~^]/-}"
}

function escapeLaTexLabel_test_001_0002() {

  local -r result="$(escapeLaTexLabel "abc_def&ghi%klm$nop#qrs{tuv}xyz~!^")"

  test "${result}" == "abc-def-ghi-klm-qrs-tuv-xyz-!-"
}

function escapeAndDetokenizeLaTex() {

  local line="$*"

  #
  # Don't use printf here
  #
  echo -n "\detokenize{"
  escapeLaTex "${line}"
  echo -n "}"
}

function escapeAndDetokenizeLaTex_test_001_0001() {

  local -r input="Rights on the lender to protect them against loss. furthe rNtoes: Logically, considering the two parties, they both have protecxtion mechanisms. so while the lender has protecxtion mechanisms through mortgage insurance, and the consumer has protextion mechanisms such as good faith estimates. also the agencies (see Consumer Protection Agency), an instance of which is the CFPB in the US (just set up). Lender rights are: - expressed in the Contract Consumer protection develops becaues the contract is written by the potential Lender. So the rights are introcued to rectify the imbalance between the two parties. Same goes for insurance. consumer protection laws (governe dby the relevant consumer protection agency. So the lender protexts itself as it writes th contract AND does the things it needs to do to protext itself, but on the approval process, and with later instruments such as insurance. Interestingly., it is the Borrower who pays for this by paying for credit reports etc. So the borrower protects itself by other mechanisms. Caveat emptor - displaced by regulation (the buyer is protected by regulation). Uberimae Fidae - in the utmost good faith. Mortgage Insurance is an additional means of mitigating the risk, that the lended may have., so if the information assessed is not accurate, or if the borrower's situation changes for the worse. then the risk rating may go down. So the Mortgage Insurance is a further strategy which mitigates any shortfall in the Lender Righrs that you may have - ie someone guarantees. In the US you can also avoid that by having paid a deposit. PIMI: Principal, Interst and Morgage Insurance. So the Borrower pays towards the MI, esxcept if they have paid a given amount as deposit. there are 2 types of MI: 1. protects the lender in the event of borrower degault 2. Insurance for \"Incapacity to pay the mortage\" (these can be bought off the shelf - can combine health, unemployment etc.). - this is the Borrower mitigating their own risk. Prevents foreclosure. Similar to general sickness etc. Where the lender charges for MI, the cost is passed onto the Borrower. e.g. if there is a % valuation (e.g. 70% in Aus, 80% in US for example) then no insurance is required."

  echo "$(escapeAndDetokenizeLaTex "${input}")"
}

#
# Return true if running inside a docker container.
# See https://stackoverflow.com/a/41559867/1110667
#
function isRunningInDockerContainer() {

  grep docker /proc/1/cgroup -qa >/dev/null 2>&1
}

#
# Return all the .rdf files that go into "dev"
#
function getDevOntologies() {

  requireValue ontology_product_tag_root || return $?

  ${FIND} "${ontology_product_tag_root}" \
    -path '*/etc*' -prune -o \
    -name '*About*' -prune -o \
    -name 'ont-policy.rdf' -prune -o \
    -name '*.rdf' -print
}

#
# Return all the .rdf files that go into "prod"
#
function getProdOntologies() {

  requireValue ontology_product_tag_root || return $?

  ${GREP} -rl 'utl-av[:;.]Release' "${ontology_product_tag_root}" | \
    ${GREP} -F ".rdf" | \
    ${GREP} -v ont-policy.rdf | \
    ${GREP} -v '*About*' | \
    ${GREP} -v '/etc/'
}


function getIsDarkMode() {

  [ -n "${ONTPUB_IS_DARK_MODE}" ] && return ${ONTPUB_IS_DARK_MODE}
  [ -n "${is_dark_mode}" ] && return ${is_dark_mode}

  if isMacOSX ; then
    #
    # In Mac OS X Mojave we can detect Dark mode
    #
    if [ "$(defaults read -g AppleInterfaceStyle)" == "Dark" ] ; then
      return 0
    fi
    return 1
  fi

  #
  # In a Jenkins context we also use dark mode because the Blue Ocean logs show dark mode.
  # The normal Jenkins UI does not but can support it.
  #
  if [ -n "${WORKSPACE}" ] ; then
    return 0
  fi

  return 1
}

declare -r -g is_dark_mode=$(getIsDarkMode ; echo $?)
