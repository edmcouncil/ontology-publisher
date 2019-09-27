#!/usr/bin/env bash
#
# Generate the htmlpages "product"
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

export SCRIPT_DIR="${SCRIPT_DIR}" # Yet another hack to silence IntelliJ
export speedy="${speedy:-0}"

function publishProductHTMLPages () {
  require TMPDIR || return $?
  require source_family_root || return $?
  require product_branch_tag || return $?
  require tag_root || return $?

  setProduct htmlpages || return $?

  FVUE_SRC_PATH="/etc/fibo-vue"
  FVUE_PATH="${TMPDIR}/fibo-vue"

  # return success if "fibo-vue" doesn't exist
  test -d "${source_family_root:?}${FVUE_SRC_PATH:?}" || return 0

  logItem "Prepare" "$(logFileName "${FVUE_PATH:?}")"
  rm -rf "${FVUE_PATH:?}" &>/dev/null || return $?
  logItem "Copy" "$(logFileName "${source_family_root:?}${FVUE_SRC_PATH:?} -> ${FVUE_PATH:?}")"
  cp -a "${source_family_root:?}${FVUE_SRC_PATH:?}" "${FVUE_PATH:?}"

  pushd "${FVUE_PATH:?}"
  logItem "npm --unsafe-perm install" "$(logFileName "${FVUE_PATH:?}")"
  env HOME="${TMPDIR:?}" npm --unsafe-perm install 2>&1 || return $?
  logItem "npm run build" "$(logFileName "${FVUE_PATH:?}")"
  env HOME="${TMPDIR:?}" npm --unsafe-perm run build 2>&1 || return $?
  popd

  logItem "copy" "$(logFileName "${FVUE_PATH:?}/dist/${product_branch_tag:?} -> ${tag_root}")"
  rm -rf "${tag_root:?}" && cp -a "${FVUE_PATH:?}/dist/${product_branch_tag:?}" "${tag_root:?}" 2>&1 || return $?

  touch "${tag_root:?}/htmlpages.log"

  return $?
}
