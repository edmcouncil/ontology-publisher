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

  logItem "Generating" "$(logFileName "${fibopedia_product_tag_root}/modules.rdf")"

  java \
    -cp /usr/share/java/saxon/saxon9he.jar \
    net.sf.saxon.Transform \
      -o:${fibopedia_product_tag_root}/modules.rdf \
      -xsl:${fibopedia_script_dir}/fibomodules.xsl \
      ${ontology_product_tag_root}/MetadataFIBO.rdf \
      debug=y

  logItem "Generating" "$(logFileName "${fibopedia_product_tag_root}/modules-clean.rdf")"

  java \
    -cp /usr/share/java/saxon/saxon9he.jar \
    net.sf.saxon.Transform \
      -o:${fibopedia_product_tag_root}/modules-clean.rdf \
      -xsl:${fibopedia_script_dir}/strip-unused-ns.xsl \
      ${fibopedia_product_tag_root}/modules.rdf

  logItem "Generating" "$(logFileName "${fibopedia_product_tag_root}/FIBOpedia.html")"

  java \
    -cp /usr/share/java/saxon/saxon9he.jar \
    net.sf.saxon.Transform \
      -o:${fibopedia_product_tag_root}/FIBOpedia.html \
      -xsl:${fibopedia_script_dir}/format-modules.xsl \
      ${fibopedia_product_tag_root}/modules-clean.rdf

  logItem "Generating" "$(logFileName "${fibopedia_product_tag_root}/FIBOpedia.csv")"

  java \
    -cp /usr/share/java/saxon/saxon9he.jar \
    net.sf.saxon.Transform \
      -o:${fibopedia_product_tag_root}/FIBOpedia.csv \
      -xsl:${fibopedia_script_dir}/csv-modules.xsl \
      ${fibopedia_product_tag_root}/modules-clean.rdf

logItem "Generating" "$(logFileName "${fibopedia_product_tag_root}/FIBOpedia.xslx")"
      
  ${PYTHON3} ${SCRIPT_DIR}/lib/csv-to-xlsx.py \
    "${fibopedia_product_tag_root}/FIBOpedia.csv" \
    "${fibopedia_product_tag_root}/FIBOpedia.xlsx" \
    "${fibopedia_script_dir}/csvconfig"

  touch "${fibopedia_product_tag_root}/fibopedia.log"
}
