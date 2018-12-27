#!/usr/bin/env bash
#
# Generate the fibopedia "product" from the source ontologies
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

export SCRIPT_DIR="${SCRIPT_DIR}" # Yet another hack to silence IntelliJ
export speedy="${speedy:-0}"

function publishProductFIBOpedia () {

  logRule "Publishing the fibopedia product"

  setProduct ontology || return $?
  export ontology_product_tag_root="${tag_root:?}"

  setProduct fibopedia || return $?
  export fibopedia_product_tag_root="${tag_root:?}"

  export fibopedia_script_dir="${SCRIPT_DIR}/product/fibopedia"

  ls

  java \
    -cp /usr/share/java/saxon/saxon9he.jar \
    net.sf.saxon.Transform \
      -o:${fibopedia_product_tag_root}/modules.rdf \
      -xsl:${fibopedia_script_dir}/fibomodules.xsl \
      ${ontology_product_tag_root}/MetadataFIBO.rdf \
      debug=y
  java \
    -cp /usr/share/java/saxon/saxon9he.jar \
    net.sf.saxon.Transform \
      -o:${fibopedia_product_tag_root}/modules-clean.rdf \
      -xsl:${fibopedia_script_dir}/strip-unused-ns.xsl \
      ${fibopedia_product_tag_root}/modules.rdf
  java \
    -cp /usr/share/java/saxon/saxon9he.jar \
    net.sf.saxon.Transform \
      -o:${fibopedia_product_tag_root}/FIBOpedia.html \
      -xsl:${fibopedia_script_dir}/format-modules.xsl \
      ${fibopedia_product_tag_root}/modules-clean.rdf
}
