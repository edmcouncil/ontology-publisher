#!/usr/bin/env bash
#
# Generate the book "product" from the source ontologies
#
# Copyright (c) agnos.ai UK Ltd, 2018
# Author Jacobus Geluk
# Licensed under MIT License
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

export SCRIPT_DIR="${SCRIPT_DIR}" # Yet another hack to silence IntelliJ
export speedy="${speedy:-0}"

if [ -f ${SCRIPT_DIR}/product/book/build-queries.sh ] ; then
  # shellcheck source=build-cats.sh
  source ${SCRIPT_DIR}/product/book/build-queries.sh
else
  source build-queries.sh # This line is only there to make the IntelliJ Bash plugin see build-queries.sh
fi

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

  mkdir -p "${book_latex_dir}/data" >/dev/null 2>&1
  
  book_stat_number_of_classes_without_superclass=0
  book_stat_number_of_classes=0
  book_stat_number_of_classes_without_label=0

  bookGenerateTdb2Database || return $?
  bookQueryListOfSuperClasses || return $?
  bookQueryListOfClasses || return $?

  for documentClass in book report ; do
    for pageSize in letter a4 ; do
      book_latex_file="${book_latex_dir}/${documentClass}-${pageSize}.tex"
      book_pdf_file="${book_latex_dir}/${documentClass}-${pageSize}.pdf"
      rm -f "${book_latex_file}" >/dev/null 2>&1
      rm -f "${book_pdf_file}" >/dev/null 2>&1
      bookGenerateLaTex "${documentClass}" "${pageSize}" || return $?
      bookGeneratePdf "${documentClass}" "${pageSize}" || return $?
    done
  done

  return 0
}

function bookGeometry() {

  local -r documentClass="$1"
  local -r pageSize="$2"

  case ${documentClass} in
    book)
      echo "${pageSize}paper, portrait, margin=1in"
      ;;
    *)
      echo "${pageSize}paper, portrait, margin=0.7in"
      ;;
  esac
}

function bookGenerateLaTex() {

  local -r documentClass="$1"
  local -r pageSize="$2"

  #
  # The preamble, see https://en.wikibooks.org/wiki/LaTeX/Document_Structure
  #
  cat > "${book_latex_file}" << __HERE__
\documentclass{${documentClass}}
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage[backend=biber,style=alphabetic,sorting=ynt]{biblatex}
\addbibresource{${book_script_dir}/book.bib}
\usepackage{enumitem}
\usepackage[hidelinks]{hyperref}
\usepackage{graphicx}
\usepackage{blindtext}
\usepackage{geometry}
\geometry{$(bookGeometry "${documentClass}" "${pageSize}")}
__HERE__

  bookGenerateTitle || return $?

  cat >> "${book_latex_file}" << __HERE__
\begin{document}
\maketitle
__HERE__

  bookGenerateAbstract "${documentClass}" || return $?

  cat >> "${book_latex_file}" <<< "\tableofcontents{}"

  bookGenerateIntro || return $?
  bookGenerateListOfClasses "${documentClass}" "${pageSize}" || return $?
  bookGenerateConclusion || return $?

  cat >> "${book_latex_file}" << __HERE__
\medskip
\printbibliography[heading=bibintoc]
\end{document}
__HERE__

  return 0
}

function bookGenerateTitle() {

  cat >> "${book_latex_file}" << __HERE__
\title{FIBO Glossary}
\author{EDM Council}
\date{\today}
__HERE__

  return 0
}

function bookGenerateAbstract() {

  local -r documentClass="$1"

  [ "${documentClass}" == "book" ] && return 0

  cat >> "${book_latex_file}" << __HERE__
\begin{abstract}
\blindtext
\end{abstract}
__HERE__

  return 0
}

function bookGenerateIntro() {

  cat >> "${book_latex_file}" << __HERE__
\section{Introduction}
\subsection{What is FIBO?}
The \textit{Financial Industry Business Ontology} (FIBO)\cite{fiboprimer} is the industry standard resource for the definitions
of business concepts in the financial services industry.
It is developed and hosted by the \textit{Enterprise Data Management Council} (EDM Council) and is published in a number for
formats for operating use and for business definitions.
It is also standardized through the \textit{Object Management Group} (OMG)\cite{omgwebsite,omgedmcwebsite}.
FIBO is developed as a series of ontologies in the \textit{Web Ontology Language} (OWL).
As such it is not a data model but a representation of the “things in the world” of financial services.
The use of logic ensures that each real-world concept is framed in a way that is unambiguous and that is readable
both by humans and machines.
These common concepts have been reviewed by EDM Council member firms over a period of years and represent a consensus
of the common concepts as understood in the industry and as reflected in industry data models and message standards.
\subsection{About this document}
\blindtext
__HERE__

  return 0
}

function bookGenerateConclusion() {

  cat >> "${book_latex_file}" << __HERE__
\section{Conclusion}
\blindtext
__HERE__

  return 0
}

function bookGenerateListOfClasses() {

  local -r documentClass="$1"
  local -r pageSize="$2"

  logRule "Step: bookGenerateListOfClasses ${documentClass} ${pageSize}"

  cat >> "${book_latex_file}" << __HERE__
\section{Classes}
This chapter enumerates all the (OWL) classes that play a role in ${family}.
Per Class we show the following information:
\begin{description}
\item [Title] The so-called "local name" of the OWL class, prefixed with the standard prefix for its namespace. See Namespace below.
\item [Label] The english label of the given OWL Class.
\item [Namespace] The namespace in which the OWL Class resides, leaving out the local name.
\item [Definition] The definition of the OWL Class.
\item [Explanatory Note] An optional explanatory note.
\end{description}
__HERE__


  local classIRI
  local prefName
  local namespace
  local classLabel
  local definition
  local explanatoryNote

  #
  # Process each line of the TSV file with "read -a" which properly deals
  # with spaces in class labels and definitions etc.
  #
  while IFS=$'\t' read -a line ; do

    [ "${line[0]}" == "" ] && continue
    [ "${line[1]}" == "" ] && continue
    [ "${line[0]:0:1}" == "?" ] && continue

    classIRI="$(stripQuotes "${line[0]}")"
    prefName="$(stripQuotes "${line[1]}")"
    namespace="$(stripQuotes "${line[2]}")"
    classLabel="$(stripQuotes "${line[3]}")"
    definition="$(stripQuotes "${line[4]}")"
    explanatoryNote="$(stripQuotes "${line[5]}")"

#    logVar classIRI
#    logVar prefName
#    logVar namespace
#    logVar classLabel
#    logVar definition

    latexSection="$(escapeLaTex "${prefName}")"

    cat >> "${book_latex_file}" << __HERE__
\subsection{${latexSection}} \label{${latexSection}}
\begin{description}
__HERE__
    #
    # Label
    #
    if [ -n "${classLabel}" ] ; then
      cat >> "${book_latex_file}" <<< "\item [Label] $(escapeLaTex "${classLabel}")"
    else
      book_stat_number_of_classes_without_label=$((book_stat_number_of_classes_without_label + 1))
    fi
    #
    # Namespace
    #
    cat >> "${book_latex_file}" <<< "\item [Namespace] {\fontsize{8}{1.2}\selectfont $(escapeLaTex "${namespace}")}"
    #
    # Super classes
    #
    bookGenerateListOfSuperClasses "${classIRI}" || return $?
    #
    # Definition
    #
    [ -n "${definition}" ] && cat >> "${book_latex_file}" <<< "\item [Definition] $(escapeLaTex "${definition}")"
    #
    # Explanatory Note
    #
    [ -n "${explanatoryNote}" ] && cat >> "${book_latex_file}" <<< "\item [Explanatory note] $(escapeLaTex "${explanatoryNote}")"

    cat >> "${book_latex_file}" <<< "\end{description}"

    book_stat_number_of_classes=$((book_stat_number_of_classes + 1))
  done < "${book_latex_dir}/data/list-of-classes.tsv"

    cat >> "${book_latex_file}" << __HERE__
\section{Statistics}
TODO: To be extended with some more interesting numbers.
\begin{description}
\item [Number of classes] ${book_stat_number_of_classes}
\begin{description}
\item [Without a label] ${book_stat_number_of_classes_without_label}
\item [Without a superclass] ${book_stat_number_of_classes_without_superclass}
\end{description}
\end{description}
__HERE__

  if ((book_stat_number_of_classes == 0)) ; then
    error "Didn't process any classes, something went wrong"
    return 1
  fi

    cat >> "${book_latex_file}" << __HERE__
__HERE__

  return 0
}

function bookGenerateListOfSuperClasses() {

  local -r classIRI="$1"
  local -r data="${book_latex_dir}/data/list-of-super-classes.tsv"

  if [ ! -f "${data}" ] ; then
    error "Could not find ${data}"
    return 1
  fi

  local -r numberOfSuperClasses=$(${SED} -n -e "s@^\"${classIRI}\"\(.*\)@\1@p" "${data}" | wc -l)

  if ((numberOfSuperClasses == 0)) ; then
    warning "${classIRI} does not have any super classes"
    book_stat_number_of_classes_without_superclass=$((book_stat_number_of_classes_without_superclass + 1))
    return 0
  fi

  if ((numberOfSuperClasses > 1)) ; then
    cat >> "${book_latex_file}" << __HERE__
\item [Superclasses]
\break
\begin{itemize}[noitemsep]
__HERE__
  fi

  #
  # Process each line of the TSV file with "read -a" which properly deals
  # with spaces in class labels and definitions etc.
  #
  while IFS=$'\t' read -a line ; do

    [ "${line[0]}" == "" ] && continue
    [ "${line[1]}" == "" ] && continue
    [ "${line[0]:0:1}" == "?" ] && continue

#   superClassIRI="$(stripQuotes "${line[0]}")"
    superClassPrefName="$(escapeLaTex "$(stripQuotes "${line[1]}")")"

#    logVar superClassIRI
#    logVar superClassPrefName

    if ((numberOfSuperClasses > 1)) ; then
      cat >> "${book_latex_file}" <<< "\item ${superClassPrefName} (\ref{${superClassPrefName}} at page \pageref{${superClassPrefName}})"
    else
      cat >> "${book_latex_file}" <<< "\item [Superclass] ${superClassPrefName} (\ref{${superClassPrefName}} at page \pageref{${superClassPrefName}})"
    fi

  done < <(
    ${SED} -n -e "s@^\"${classIRI}\"\(.*\)@\1@p" "${data}"
  )

  if ((numberOfSuperClasses > 1)) ; then
    cat >> "${book_latex_file}" <<< "\end{itemize}"
  fi

}

function escapeLaTex() {

  local line="$*"

  line="${line//#/\\#}"
  line="${line//&/\\&}"

  echo "${line}"
}

function bookGeneratePdf() {

  local -r documentClass="$1"
  local -r pageSize="$2"

  log "bookGeneratePdf documentClass=${documentClass} pageSize=${pageSize}"

  (
    cd "${book_latex_dir}" || return $?
    pdflatex \
      -halt-on-error \
      -draftmode \
      "${book_latex_file}"
    pdflatex \
      -halt-on-error \
      -output-format=pdf \
      "${book_latex_file}"
  )
  return $?
}