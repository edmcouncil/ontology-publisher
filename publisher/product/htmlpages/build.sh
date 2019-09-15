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

  logItem "Prepare" "$(logFileName "${FVUE_PATH:?}")"
  rm -rf "${FVUE_PATH:?}" &>/dev/null || return $?
  logItem "Copy" "$(logFileName "${source_family_root:?}${FVUE_SRC_PATH:?} -> ${FVUE_PATH:?}")"
  cp -a "${source_family_root:?}${FVUE_SRC_PATH:?}" "${FVUE_PATH:?}"

  logItem "npm --unsafe-perm install" "$(logFileName "${FVUE_PATH:?}")"
  env HOME="${TMPDIR:?}" npm --unsafe-perm --prefix "${FVUE_PATH:?}" install > "${TMPDIR:?}/htmlpages.log" 2>&1 || return $?
  logItem "npm run build" "$(logFileName "${FVUE_PATH:?}")"
  env HOME="${TMPDIR:?}" PATH="${FVUE_PATH:?}/node_modules/.bin:${PATH}" npm --prefix "${FVUE_PATH:?}" run build >> "${TMPDIR:?}/htmlpages.log" 2>&1 || return $?

  logItem "copy" "$(logFileName "${FVUE_PATH}/dist/${product_branch_tag} -> ${tag_root}")"
  rm -rf "${tag_root:?}"
  cp -av "${FVUE_PATH:?}/dist/${product_branch_tag:?}" "${tag_root:?}" >> "${TMPDIR:?}/htmlpages.log" 2>&1 || return $?
  mv -f "${TMPDIR:?}/htmlpages.log" "${tag_root:?}"/htmlpages.log

  return $?
}
