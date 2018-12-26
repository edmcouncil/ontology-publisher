#!/usr/bin/env bash
#
# Generate the book "product" from the source ontologies
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

export SCRIPT_DIR="${SCRIPT_DIR}" # Yet another hack to silence IntelliJ
export speedy="${speedy:-0}"

#
# Produce all artifacts for the book product
#
function publishProductBook() {

  setProduct ontology || return $?
  export ontology_product_tag_root="${tag_root:?}"

  setProduct book || return $?
  export book_product_tag_root="${tag_root:?}"
  export book_product_tag_root_url="${tag_root_url:?}"

  book_script_dir="$(cd "${SCRIPT_DIR}/product/book" && pwd)" ; export book_script_dir
  export book_latex_dir="${book_product_tag_root}"
  export book_latex_file="${book_latex_dir}/book.tex"
  export book_pdf_file="${book_latex_dir}/book.pdf"

  rm -f "${book_latex_file}" >/dev/null 2>&1
  rm -f "${book_pdf_file}" >/dev/null 2>&1

  bookGenerateTdb2Database || return $?
  bookGenerateLaTex || return $?
  bookGeneratePdf || return $?

  return 0
}

function bookGenerateTdb2Database() {

  require book_latex_dir || return $?
  require ontology_product_tag_root || return $?

  if [ -d "${book_latex_dir}/tdb2" ] ; then
    warning "Skipping recreation of ${book_latex_dir}/tdb2"
    return 0
  fi

  tdb2.tdbloader \
    --loc="${book_latex_dir}/tdb2" \
    --loader="phased" \
    --verbose \
    $(${FIND} "${ontology_product_tag_root}" -name "*.rdf")
}

function bookGenerateLaTex() {

  cat > "${book_latex_file}" << __HERE__
\documentclass{article}
\usepackage[utf8]{inputenc}
\usepackage{natbib}
\usepackage{graphicx}
\usepackage{blindtext}
__HERE__

  bookGenerateTitle || return $?

  cat >> "${book_latex_file}" << __HERE__
\begin{document}

\maketitle
__HERE__

  bookGenerateIntro || return $?
  bookGenerateListOfClasses || return $?
  bookGenerateConclusion || return $?

  cat >> "${book_latex_file}" << __HERE__
\bibliographystyle{plain}
\bibliography{references}
\end{document}
__HERE__

  return 0
}

function bookGenerateTitle() {

  cat >> "${book_latex_file}" << __HERE__
\title{FIBO Glossary}
\date{December 2018}
__HERE__

  return 0
}

function bookGenerateIntro() {

  cat >> "${book_latex_file}" << __HERE__
\section{Introduction}
There is a theory which states that if ever anyone discovers exactly what the Universe is for and why it is here,
it will instantly disappear and be replaced by something even more bizarre and inexplicable.
There is another theory which states that this has already happened.
__HERE__

  return 0
}

function bookGenerateConclusion() {

  cat >> "${book_latex_file}" << __HERE__
\section{Conclusion}
``I always thought something was fundamentally wrong with the universe'' \citep{adams1995hitchhiker}
__HERE__

  return 0
}

function bookGenerateListOfClasses() {

  cat > "${TMPDIR}/book-list-of-classes.sq" << __HERE__
#
# Get a list of all the class names
#
PREFIX afn: <http://jena.apache.org/ARQ/function#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix skos: <http://www.w3.org/2004/02/skos/core#>

SELECT ?class (group_concat(?prefixedName ; separator = "") as ?prefName) WHERE {
  VALUES (?prefix ?ns) {
$(grep --no-filename -r '<!ENTITY' /input/* | sort -u | sed 's/.*<!ENTITY \(.*\) "\(.*\)">/("\1:" <\2>)/g')
    ( "ex1:" <http://example1.com/> )
    ( "ex2:" <http://example2.com/> )
    ( "ex3:" <http://example3.com/> )
  }
  ?class a owl:Class .
  ?class rdfs:label ?classLabel .

  BIND(
    IF(
      STRSTARTS(STR(?class), STR(?ns)),
      CONCAT(
        ?prefix,
        STRAFTER(STR(?class), STR(?ns))
      ),
      ""
    ) AS ?prefixedName
  )

  FILTER (lang(?classLabel) = 'en')
  BIND(STR(?classLabel) AS ?strClassLabel)
}
GROUP BY ?class
ORDER BY ?class
__HERE__

    cat >> "${book_latex_file}" << __HERE__
\section{Classes}
All the classes:
\begin{description}
__HERE__

  while read classIRI prefixedName ; do
    classIRI="$(stripQuotes "${classIRI}")"
    prefixedName="$(stripQuotes "${prefixedName}")"
    cat >> "${book_latex_file}" << __HERE__
\item [${prefixedName}] \blindtext
__HERE__
  done < <(
    tdb2.tdbquery \
      --loc="${book_latex_dir}/tdb2" \
      --query="${TMPDIR}/book-list-of-classes.sq" \
      --results=TSV
  )

    cat >> "${book_latex_file}" << __HERE__
\end{description}
__HERE__

  return 0
}

function bookGeneratePdf() {

  log "bookGeneratePdf"

  (
    cd "${book_latex_dir}" || return $?
    pdflatex \
      -halt-on-error \
      -output-format=pdf \
      "${book_latex_file}"
  )
  return $?
}