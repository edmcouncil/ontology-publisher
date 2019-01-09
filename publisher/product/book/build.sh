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
# You can limit the number of classes here to for instance 100 so that generating the book
# doesn't take so long which is useful during development.
#
book_max_classes=10000
#book_max_classes=30

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
  book_latex_dir="${book_product_tag_root}"
  book_data_dir="${book_product_tag_root}/data"
  book_query_dir="${book_product_tag_root}/query"

  mkdir -p "${book_data_dir}" "${book_query_dir}" >/dev/null 2>&1

  export BIBINPUTS="${book_script_dir}"

  #
  # Various stats that we maintain during generation of the book, to be printed in the Statistics chapter
  #
  book_stat_number_of_ontologies=0
  book_stat_number_of_ontologies_without_label=0
  book_stat_number_of_classes_without_superclass=0
  book_stat_number_of_classes=0
  book_stat_number_of_classes_without_label=0

  declare -A book_array_ontologies
  declare -A book_array_classes

  bookGenerateTdb2Database || return $?
  bookGeneratePrefixesAsSparqlValues || return $?
  bookQueryListOfClasses || return $?

  #
  # Remove all generated files
  #
  for documentClass in book report ; do
    for pageSize in letter a4 ; do
      book_base_name="${documentClass}-${pageSize}"
      book_file_noext="${book_latex_dir}/${book_base_name}"
      glos_file_noext="${book_latex_dir}/${book_base_name}-glossary"
      rm -vf "${book_file_noext}".* "${glos_file_noext}".*
    done
  done

  for documentClass in book report ; do
    for pageSize in letter a4 ; do
      book_base_name="${documentClass}-${pageSize}"
      logRule "Step: bookGenerate ${book_base_name}"
      book_file_noext="${book_latex_dir}/${book_base_name}"
      glos_file_noext="${book_latex_dir}/${book_base_name}-glossary"
      book_tex_file="${book_file_noext}.tex"
      glos_tex_file="${glos_file_noext}.tex"
      exec 3<> "${book_tex_file}"
      exec 4<> "${glos_tex_file}"
      bookGenerateLaTex "${documentClass}" "${pageSize}" || return $?
      exec 3>&-
      exec 4>&-
      #
      # Sort the glossary and filter out duplicates
      #
      sort --unique --key=1,2 --field-separator='}' --output="${glos_tex_file}" "${glos_tex_file}"
      bookCompile "${documentClass}" "${pageSize}" || return $?
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
  cat >&3 << __HERE__
\documentclass[${pageSize}paper,oneside]{${documentClass}}
% \usepackage[T1]{fontenc} (use this with pdflatex but not with xelatex)
% \usepackage[utf8]{inputenc} (use this with pdflatex but not with xelatex)
\usepackage{fontspec} % use this with xelatex
\usepackage[backend=biber,style=alphabetic,sorting=ynt]{biblatex}
\addbibresource{book.bib}
\usepackage{enumitem}
\usepackage{graphicx}
\graphicspath{{/publisher/lib/images/}}
\usepackage{blindtext}
\usepackage{appendix}
\usepackage{calc}
\usepackage{geometry}
\usepackage{imakeidx}
\makeindex[intoc]
\geometry{$(bookGeometry "${documentClass}" "${pageSize}")}
%
% One must be careful when importing hyperref. Usually, it has to be the last package to be imported, but there might
% be some exceptions to this rule.
%
% See https://www.overleaf.com/learn/latex/Hyperlinks#Linking_web_addresses
%
\usepackage{hyperref}
\hypersetup{colorlinks=true,linkcolor=blue,filecolor=magenta,urlcolor=cyan}
\urlstyle{same}
\PassOptionsToPackage{hyphens}{url}\usepackage{hyperref}
%
% glossaries package has to come after hyperref
% See http://mirrors.nxthost.com/ctan/macros/latex/contrib/glossaries/glossariesbegin.html
%
\usepackage[acronym,toc]{glossaries}
\loadglsentries{${book_base_name}-glossary}
\makeglossaries
__HERE__

  bookCreateGlossaryFile || return $?

  cat >&3 << __HERE__
\begin{document}
%\maketitle
__HERE__

  bookGenerateTitle || return $?

  cat >&3 <<< "\part{Intro}"

  bookGenerateAbstract "${documentClass}" || return $?

  cat >&3 <<< "\setcounter{tocdepth}{2}"
  cat >&3 <<< "\tableofcontents{}"

  bookGenerateSectionIntro || return $?

  cat >&3 <<< "\part{Reference}"

  bookGenerateSectionOntologies "${documentClass}" "${pageSize}" || return $?
  bookGenerateSectionClasses "${documentClass}" "${pageSize}" || return $?
  bookGenerateSectionProperties "${documentClass}" "${pageSize}" || return $?
  bookGenerateSectionIndividuals "${documentClass}" "${pageSize}" || return $?
  bookGenerateSectionConclusion || return $?

  cat >&3 <<< "\part{Appendices}"
  cat >&3 <<< "\appendix"
  cat >&3 <<< "\addappheadtotoc"

  bookGenerateSectionPrefixes || return $?
  bookGenerateSectionStatistics || return $?

  cat >&3 << __HERE__
\setglossarystyle{altlist}
\glsaddall
\printglossary[type=\acronymtype]
\glsaddall
\printglossary[title=Glossary, toctitle=Glossary]
\printbibliography[heading=bibintoc]
\printindex
\end{document}
__HERE__

  return 0
}

function bookCreateGlossaryFile() {

  cat >&4 << __HERE__
\newacronym{rdf}{RDF}{Resource Definition Framework}
\newacronym{owl}{OWL}{Web Ontology Language}
\newacronym{fibo}{FIBO}{Financial Industry Business Ontology}
\newacronym{omg}{OMG}{Object Management Group}
\newacronym{edmc}{EDM Council}{Enterprise Data Management Council}
__HERE__

  return 0
}

function bookAddGlossaryTerm() {

  local -r label="$(escapeLaTexLabel "$1")"
  local -r name="$(escapeLaTex "$1")"
  # shellcheck disable=SC2155
  local description="$(escapeLaTex "$2")"
  #
  # Remove the last dot from the line if its there because LaTex will add it again
  #
  [ "${description: -1}" == "." ] && description="${description::-1}"

  cat >&4 << __HERE__
\newglossaryentry{${label}}{name={${name}},description={${description}}}
__HERE__

}

function bookGenerateTitle() {

  cat >&3 << __HERE__
\begin{titlepage}

\newcommand{\HRule}{\rule{\linewidth}{0.5mm}}

\center

\textsc{\LARGE Enterprise Data Management Council}\\\\[1.5cm]
\textsc{\Large FIBO}\\\\[0.5cm]
\textsc{\large Financial Industry Business Ontology}\\\\[0.5cm]

\HRule \\\\[0.4cm]
{ \huge \bfseries Reference}\\\\[0.4cm]
\HRule \\\\[1.5cm]

{\large \today}\\\\[2cm]

\includegraphics{edmcouncil-logo-large}\\\\[1cm]

\vfill

\end{titlepage}
__HERE__

  return 0
}

function bookGenerateAbstract() {

  local -r documentClass="$1"

  [ "${documentClass}" == "book" ] && return 0

  cat >&3 << __HERE__
\begin{abstract}
\blindtext
\end{abstract}
__HERE__

  return 0
}

function bookGenerateSectionIntro() {

  cat >&3 << __HERE__
\chapter*{What is FIBO?}

  The \textit{\acrfull{fibo}}\cite{fiboprimer} is the industry standard resource for
  the definitions of business concepts in the financial services industry.
  It is developed and hosted by the \textit{\acrfull{edmc}} and is published in a
  number for formats for operating use and for business definitions.
  It is also standardized through the \textit{\acrfull{omg}}\cite{omgwebsite,omgedmcwebsite}.
  \acrshort{fibo} is developed as a series of ontologies in the \textit{\acrfull{owl}}.
  As such it is not a data model but a representation of the “things in the world” of financial services.
  The use of logic ensures that each real-world concept is framed in a way that is unambiguous and that is readable
  both by humans and machines.
  These common concepts have been reviewed by \acrshort{edmc} member firms over a period of years and represent a
  consensus of the common concepts as understood in the industry and as reflected in industry data models and message
  standards.

\chapter*{About this document}

  This document is generated by the ontology-publisher\cite{ontology-publisher} which used the FIBO ontologies
  that are hosted on Github{fibo-github} (in a members-only repository).

__HERE__

  return 0
}

function bookGenerateSectionConclusion() {

  cat >&3 << __HERE__
\chapter{Conclusion}
\blindtext
__HERE__

  return 0
}

function bookGenerateSectionOntologies() {

  local -r documentClass="$1"
  local -r pageSize="$2"
  local ontologyIRI
  local ontologyVersionIRI
  local ontologyLabel
  local abstract
  local preferredPrefix
  local maturityLevel

  logRule "Step: bookGenerateSectionOntologies ${book_base_name}"

  bookQueryListOfOntologies || return $?

  logVar book_results_file

  cat >&3 << __HERE__
\chapter{Ontologies}

  This chapter enumerates all the (OWL) ontologies that play a role in ${family}.

__HERE__

  #
  # Process each line of the TSV file with "read -a" which properly deals
  # with spaces in class labels and definitions etc.
  #
  # ?ontologyIRIstr	?ontologyVersionIRIstr	?ontologyPrefix	?ontologyLabelStr
  # ?abstractStr	?preferredPrefixStr	?maturityLevelStr
  #
  while IFS=$'\t' read ontologyIRI ontologyVersionIRI prefix ontologyLabel abstract preferredPrefix maturityLevel ; do

    [ "${ontologyIRI}" == "" ] && continue
    [ "${ontologyIRI:0:1}" == "?" ] && continue

    ontologyIsInTestDomain "${ontologyIRI}" || continue

    ontologyIRI="$(stripQuotes "${ontologyIRI}")"
    ontologyVersionIRI="$(stripQuotes "${ontologyVersionIRI}")"
    prefix="$(stripQuotes "${prefix}")"
    ontologyLabel="$(stripQuotes "${ontologyLabel}")"
    abstract="$(stripQuotes "${abstract}")"
    preferredPrefix="$(stripQuotes "${preferredPrefix}")"
    maturityLevel="$(stripQuotes "${maturityLevel}")"

    logRule "Ontology:"
    logVar ontologyIRI
    logVar ontologyVersionIRI
    logVar prefix
    logVar ontologyLabel
    logVar abstract
    logVar preferredPrefix
    logVar maturityLevel

    if [ "${prefix}" == "" ] ; then
      prefix="${preferredPrefix}"
      preferredPrefix=""
    fi

    if [ "${ontologyLabel}" == "${prefix}" ] ; then
      ontologyLaTexLabel=""
      ontologyLabel=""
    else
      ontologyLaTexLabel="$(escapeLaTexLabel "${ontologyLabel}")"
      ontologyLabel="$(escapeLaTex "${ontologyLabel}")"
    fi

    if [ -n "${prefix}" ] ; then
      cat >&3 << __HERE__
{\renewcommand\addcontentsline[3]{} \section{${prefix}}}
\label{sec:${prefix}} \index{${prefix}}
__HERE__
    elif [ -n "${ontologyLabel}" ] ; then
      cat >&3 << __HERE__
{\renewcommand\addcontentsline[3]{} \section{${ontologyLabel}}}
\label{sec:${ontologyLaTexLabel}} \index{${ontologyLabel}}
__HERE__
    else
      continue
    fi

    #
    # Label
    #
    if [ -n "${ontologyLabel}" ] ; then
      cat >&3 <<< "\textbf{$(escapeAndDetokenizeLaTex "${ontologyLabel}")} \\\\"
      if [ -n "${prefix}" ] && [ -n "${abstract}" ] ; then
        bookAddGlossaryTerm "${prefix}" "${abstract}"
      fi
    else
      book_stat_number_of_ontologies_without_label=$((book_stat_number_of_ontologies_without_label + 1))
    fi
    #
    # abstract
    #
    if [ -n "${abstract}" ] ; then
      cat >&3 <<< "$(escapeAndDetokenizeLaTex "${abstract}")"
    else
      cat >&3 <<< "No abstract available."
    fi

    cat >&3 <<< "\\\\"
    cat >&3 <<< "\begin{description}[topsep=1.0pt]"
    #
    # Preferred prefix
    #
    if [ -n "${preferredPrefix}" ] ; then
      cat >&3 <<< "\item [Prefix] $(escapeAndDetokenizeLaTex "${preferredPrefix}")"
    fi
    #
    # Maturity level
    #
    if [ -n "${maturityLevel}" ] ; then
      cat >&3 <<< "\item [Maturity] $(escapeAndDetokenizeLaTex "${maturityLevel}")"
    fi
    #
    # Ontology Version IRI
    #
    if [ -n "${ontologyVersionIRI}" ] ; then
      cat >&3 <<< "\item [Version IRI] \url{$(escapeAndDetokenizeLaTex "${ontologyVersionIRI}")}"
    fi

    cat >&3 <<< "\end{description}"

    book_stat_number_of_ontologies=$((book_stat_number_of_ontologies + 1))

  done < "${book_results_file}"

  return 0
}

function bookGenerateSectionClasses() {

  local -r documentClass="$1"
  local -r pageSize="$2"

  logRule "Step: bookGenerateSectionClasses ${book_base_name}"

  local book_results_file # will get the name of the results value after the call to bookQueryListOfClasses

  bookQueryListOfClasses || return $?

  cat >&3 << __HERE__
\chapter{Classes}

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
  local numberOfClasses=0

  #
  # Process each line of the TSV file with "read -a" which properly deals
  # with spaces in class labels and definitions etc.
  #
  while IFS=$'\t' read classIRI classPrefName namespace classLabel definition explanatoryNote ; do

    [ "${classIRI}" == "" ] && continue
    [ "${classPrefName}" == "" ] && continue
    [ "${classIRI:0:1}" == "?" ] && continue

    if ((numberOfClasses > book_max_classes)) ; then
      warning "Stopping at ${book_max_classes} since we're running in dev mode"
      break
    fi
    numberOfClasses=$((numberOfClasses + 1))

    classIRI="$(stripQuotes "${classIRI}")"
    classPrefName="$(stripQuotes "${classPrefName}")"
    namespace="$(stripQuotes "${namespace}")"
    classLabel="$(stripQuotes "${classLabel}")"
    definition="$(stripQuotes "${definition}")"
    explanatoryNote="$(stripQuotes "${explanatoryNote}")"

#    logVar classIRI
#    logVar classPrefName
#    logVar namespace
#    logVar classLabel
#    logVar definition

    classLaTexLabel="$(escapeLaTexLabel "${classPrefName}")"
    classPrefName="$(escapeLaTex "${classPrefName}")"

    cat >&3 << __HERE__
{\renewcommand\addcontentsline[3]{} \section{${classPrefName}}}
\label{sec:${classLaTexLabel}} \index{${classPrefName#*:}}
__HERE__

    #
    # Label
    #
    if [ -n "${classLabel}" ] ; then
      cat >&3 <<< "\textbf{$(escapeAndDetokenizeLaTex "${classLabel}")} \\\\"
      if [ -n "${classLabel}" ] && [ -n "${definition}" ] ; then
        bookAddGlossaryTerm "${classLabel}" "${definition}"
      fi
    else
      book_stat_number_of_classes_without_label=$((book_stat_number_of_classes_without_label + 1))
    fi

    #
    # Definition
    #
    if [ -n "${definition}" ] ; then
      cat >&3 <<< "$(escapeAndDetokenizeLaTex "${definition}")"
    else
      cat >&3 <<< "No definition available."
    fi

    cat >&3 <<< "\\\\"
    cat >&3 <<< "\begin{description}[topsep=1.0pt]"
    #
    # Namespace
    #
    cat >&3 <<< "\item [Namespace] \hfill \\\\ {\fontsize{8}{1.2}\selectfont $(escapeAndDetokenizeLaTex "${namespace}")}"
    #
    # Super classes
    #
    bookGenerateListOfSuperclasses "${classIRI}" || return $?
    #
    # Subclasses
    #
    bookGenerateListOfSubclasses "${classIRI}" || return $?
    #
    # Explanatory Note
    #
    [ -n "${explanatoryNote}" ] && cat >&3 <<< "\item [Explanatory note] \hfill \\\\ $(escapeAndDetokenizeLaTex "${explanatoryNote}")"

    cat >&3 <<< "\end{description}"

    book_stat_number_of_classes=$((book_stat_number_of_classes + 1))
  done < "${book_results_file}"

  if ((book_stat_number_of_classes == 0)) ; then
    error "Didn't process any classes, something went wrong"
    return 1
  fi

    cat >&3 << __HERE__
__HERE__

  return 0
}

function bookGenerateSectionProperties() {

  local -r documentClass="$1"
  local -r pageSize="$2"

  logRule "Step: bookGenerateSectionProperties ${book_base_name}"

  cat >&3 << __HERE__
\chapter{Properties}

  This chapter enumerates all the (OWL) properties that play a role in ${family}.

  TODO

  \blindtext
__HERE__

  return 0
}

function bookGenerateSectionIndividuals() {

  local -r documentClass="$1"
  local -r pageSize="$2"

  logRule "Step: bookGenerateSectionIndividuals ${book_base_name}"

  cat >&3 << __HERE__
\chapter{Individuals}

  This chapter enumerates all the (OWL) properties that play a role in ${family}.

  TODO

  \blindtext
__HERE__

  return 0
}

function bookGenerateSectionPrefixes() {

  cat >&3 << __HERE__
\chapter{Prefixes}
\begin{tiny}
\begin{description}[leftmargin=6.2cm,labelwidth=\widthof{fibo-fbc-fct-eufseind}]
__HERE__

  while read prefix namespace ; do
    cat >&3 <<< "\item [${prefix}] \detokenize{${namespace}}"
  done < <( ${SED} 's/("\(.*\):"\(.*\))/\1 \2/g' "${TMPDIR}/book-prefixes.txt" )

  cat >&3 <<< "\end{description}"
  cat >&3 <<< "\end{tiny}"

  return 0
}

function bookGenerateSectionStatistics() {

    cat >&3 << __HERE__
\chapter{Statistics}

  TODO: To be extended with some more interesting numbers.

  \begin{description}
    \item [Number of ontologies] ${book_stat_number_of_ontologies}
      \begin{description}
        \item [Without a label] ${book_stat_number_of_ontologies_without_label}
      \end{description}
    \item [Number of classes] ${book_stat_number_of_classes}
      \begin{description}
        \item [Without a label] ${book_stat_number_of_classes_without_label}
        \item [Without a superclass] ${book_stat_number_of_classes_without_superclass}
      \end{description}
  \end{description}
__HERE__

  return 0
}

function bookGenerateListOfSuperclasses() {

  local -r classIRI="$1"
  local line

  local book_results_file # will get the name of the results value after the call to bookQueryListOfClasses

  bookQueryListOfSuperClasses || return $?

  if [ ! -f "${book_results_file}" ] ; then
    error "Could not find ${book_results_file}"
    return 1
  fi

  local -a superClassArray

  mapfile -t superClassArray < <(${SED} -n -e "s@^\"${classIRI}\"\(.*\)@\1@p" "${book_results_file}")

  local -r numberOfSuperClasses=${#superClassArray[*]}

  if ((numberOfSuperClasses == 0)) ; then
    warning "${classIRI} does not have any super classes"
    book_stat_number_of_classes_without_superclass=$((book_stat_number_of_classes_without_superclass + 1))
    return 0
  fi

  if ((numberOfSuperClasses > 1)) ; then
    cat >&3 << __HERE__
\item [Superclasses] \hfill
\begin{itemize}[noitemsep,nolistsep,topsep=1.0pt]
__HERE__
  fi

  #
  # Process each line of the TSV file with "read -a" which properly deals
  # with spaces in class labels and definitions etc.
  #
  for line in "${superClassArray[@]}" ; do

    set -- ${line}

    [ "$1" == "" ] && continue
    [ "$2" == "" ] && continue

#   superClassIRI="$(stripQuotes "$1")"
    superClassPrefName="$(stripQuotes "$2")"

    if ((numberOfSuperClasses > 1)) ; then
      cat >&3 <<< "\item $(bookClassReference "${superClassPrefName}")"
    else
      cat >&3 <<< "\item [Superclass] $(bookClassReference "${superClassPrefName}")"
    fi

  done

  if ((numberOfSuperClasses > 1)) ; then
    cat >&3 <<< "\end{itemize}"
  fi

}

function bookClassReference() {

  local classPrefName="$1"
  local -r classLaTexLabel="$(escapeLaTexLabel "${classPrefName}")"

  classPrefName="$(escapeLaTex "${classPrefName}")"

  echo -n "${classPrefName}"
  echo -n "\index{${classPrefName#*:}}"
  echo -n " (Section~\ref{sec:${classLaTexLabel}} at page~\pageref{sec:${classLaTexLabel}})"
}

function bookGenerateListOfSubclasses() {

  local -r classIRI="$1"

  local book_results_file # will get the name of the results value after the call to bookQueryListOfClasses

  #
  # We use the super classes list to find the subclasses of a given class
  #
  bookQueryListOfSuperClasses || return $?

  if [ ! -f "${book_results_file}" ] ; then
    error "Could not find ${book_results_file}"
    return 1
  fi

  local -a subclassArray

  mapfile -t subclassArray < <(${SED} -n -e "s@^\"\(.*\)\"\t\"${classIRI}\".*@\1@p" "${book_results_file}")

  local -r numberOfSubclasses=${#subclassArray[*]}

  if ((numberOfSubclasses == 0)) ; then
    return 0
  fi

  if ((numberOfSubclasses > 1)) ; then
    cat >&3 << __HERE__
\item [Subclasses] \hfill
\begin{itemize}[noitemsep,nolistsep,topsep=1.0pt]
__HERE__
  fi

  #
  # Process each line of the TSV file with "read -a" which properly deals
  # with spaces in class labels and definitions etc.
  #
  for line in "${subclassArray[@]}" ; do

    set -- ${line}

    [ "$1" == "" ] && continue

    subclassIRI="$(stripQuotes "$1")"
    subclassPrefLabel="${book_array_classes[${subclassIRI},prefName]}"

    [ "${subclassPrefLabel}" == "" ] && continue

    if ((numberOfSubclasses > 1)) ; then
      cat >&3 <<< "\item $(bookClassReference "${subclassPrefLabel}")"
    else
      cat >&3 <<< "\item [Subclass] $(bookClassReference "${subclassPrefLabel}")"
    fi

  done

  if ((numberOfSubclasses > 1)) ; then
    cat >&3 <<< "\end{itemize}"
  fi

}

function bookCompile() {

  local -r documentClass="$1"
  local -r pageSize="$2"

  log "bookCompile documentClass=${documentClass} pageSize=${pageSize}"

  (
    cd "${book_latex_dir}" || return $?
#      -interaction=batchmode \
    set -x
    xelatex -halt-on-error "${book_base_name}" || return $?
    makeglossaries "${book_base_name}" || return $?
    xelatex -halt-on-error "${book_base_name}" || return $?
    biber "${book_base_name}" || return $?
    xelatex -halt-on-error "${book_base_name}" || return $?
    makeindex "${book_base_name}" || return $?
    xelatex -halt-on-error "${book_base_name}" || return $?
  )
  return $?
}