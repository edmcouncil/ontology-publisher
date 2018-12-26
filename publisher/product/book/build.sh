#!/usr/bin/env bash
#
# Generate the book "product" from the source ontologies
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

#
# Produce all artifacts for the book product
#
function publishProductBook() {

  setProduct ontology || return $?
  export ontology_product_tag_root="${tag_root:?}"

  setProduct book || return $?
  export book_product_tag_root="${tag_root:?}"
  export book_product_tag_root_url="${tag_root_url:?}"

  return 0
}
