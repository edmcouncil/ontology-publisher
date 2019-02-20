#!/usr/bin/env bash
#
# Build the all.ttl file
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source ../../lib/_functions.sh

function ontologyCreateTheAllTtlFile() {

  logStep "ontologyCreateTheAllTtlFile"

  require TMPDIR || return $?
  require tag_root || return $?
  require family_product_branch_tag || return $?
  require JENA_ARQ || return $?
  require spec_root || return $?

  if [ ! -f ${SCRIPT_DIR}/lib/trigify.py ] ; then
    error "Could not find ${SCRIPT_DIR}/lib/trigify.py"
    return 1
  fi

	local rc=$?

  logDir tag_root

  if ((verbose)) ; then
    python3 ${SCRIPT_DIR}/lib/trigify.py \
      --dir=${tag_root} \
      --top="https://spec.edmcouncil.org/${family_product_branch_tag:?}/AboutFIBODev" \
      --top="https://spec.edmcouncil.org/fibo/ontology/MetadataFIBO/" \
      --output="${TMPDIR}/all.ttl" \
      --verbose \
      --format=ttl
     rc=$?
  else
    python3 ${SCRIPT_DIR}/lib/trigify.py \
      --dir=${tag_root} \
      --top="https://spec.edmcouncil.org/${family_product_branch_tag:?}/AboutFIBODev" \
      --top="https://spec.edmcouncil.org/fibo/ontology/MetadataFIBO/" \
      --output="${TMPDIR}/all.ttl" \
      --format=ttl
      rc=$?
  fi

  if ((rc != 0)) ; then
    error "An error occurred while executing trigify.py, rc=${rc}"
    return 1
  fi

  if [ ! -f "${TMPDIR}/all.ttl" ] ; then
    error "Did not generate ${TMPDIR}/all.ttl"
    return 1
  fi

  ls -la "${TMPDIR}/all.ttl" | pipelog

  cat > "${TMPDIR}/maturemodule.sq" << __HERE__
#
# Finds all the modules in FIBO that have parts that have maturily level :Release 
# Those are the ones that should 
# 
# TODO: Also, why not do this in trigify.py itself? rdflib supports SPARQL. Would save the arq startup time.
#
PREFIX fibo-fnd-utl-av: <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/>
PREFIX dct:  <http://purl.org/dc/terms/>
PREFIX sm: <http://www.omg.org/techprocess/ab/SpecificationMetadata/>

SELECT DISTINCT ?modfile WHERE {
  {
    ?mod a sm:Module ;
      dct:hasPart+ / fibo-fnd-utl-av:hasMaturityLevel fibo-fnd-utl-av:Release ;
	    sm:moduleAbbreviation ?ab ;
	  .
    BIND (CONCAT (?ab, "-mod") AS ?abont)
    ?modont
      sm:fileAbbreviation ?abont ;
      sm:filename ?modfile ;
    .
  }
  UNION {
    BIND ("MetadataFIBO.rdf" AS ?modfile)
  }
}
ORDER BY ?mod
__HERE__

# sed -i 's/\r//'  ${TMPDIR}/all.ttl
# sed -i 's/\r//'  ${TMPDIR}/maturemodule.sq

  tail "${TMPDIR}/all.ttl" | pipelog

  ${JENA_ARQ} \
    --data="${TMPDIR}/all.ttl" \
    --query="${TMPDIR}/maturemodule.sq" \
    --results=CSV \
    > ${TMPDIR}/good

  #
  # Good file should include all the modules that include Release level ontologies
  #
  log "Here are all the release-level modules:"
  head ${TMPDIR}/good | pipelog

  ${SED} -i 's/\r//' ${TMPDIR}/good

  (
    cd ${spec_root:?} || return $?
    rm -f ${TMPDIR}/prodpaths.txt
    touch ${TMPDIR}/prodpaths.txt
    chmod a+w ${TMPDIR}/prodpaths.txt
    ${SED} \
      "s@^@find ${family_product_branch_tag} -name \"@;s/.rdf/.*\"/" \
      ${TMPDIR}/good | \
      tail --lines=+2 | \
      sh > ${TMPDIR}/prodpaths.txt

    log "prodpaths"
    cat ${TMPDIR}/prodpaths.txt | pipelog
  )

  return $?
}
