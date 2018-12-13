#!/usr/bin/env bash
#
# Build the all.ttl file
#

#
# Looks silly but fools IntelliJ to see the functions in the included files
#
false && source _functions.sh

function ontologyCreateTheAllTtlFile() {

  logRule "Step: ontologyCreateTheAllTtlFile"

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
  if ((verbose)) ; then
    set -x
    python3 ${SCRIPT_DIR}/lib/trigify.py \
      --dir=${tag_root} \
      --top="https://spec.edmcouncil.org/${family_product_branch_tag:?}/AboutFIBO" \
      --top="https://spec.edmcouncil.org/fibo/ontology/MetadataFIBO/" \
      --output="${tmp_dir}/all.ttl" \
      --verbose \
      --format=ttl
     rc=$?
     set +x
  else
    python3 ${SCRIPT_DIR}/lib/trigify.py \
      --dir=${tag_root} \
      --top="https://spec.edmcouncil.org/${family_product_branch_tag:?}/AboutFIBO" \
      --top="https://spec.edmcouncil.org/fibo/ontology/MetadataFIBO/" \
      --output="${tmp_dir}/all.ttl" \
      --format=ttl
      rc=$?
  fi

  if ((rc != 0)) ; then
    error "An error occurred while executing trigify.py, rc=${rc}"
    return 1
  fi

  if [ ! -f "${tmp_dir}/all.ttl" ] ; then
    error "Did not generate ${tmp_dir}/all.ttl"
    return 1
  fi

  ls -la "${tmp_dir}/all.ttl"

  cat > "${tmp_dir}/maturemodule.sq" << __HERE__
#
# TODO: Document this SPARQL statement, what does it do?
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

# sed -i 's/\r//'  ${tmp_dir}/all.ttl
# sed -i 's/\r//'  ${tmp_dir}/maturemodule.sq

  tail "${tmp_dir}/all.ttl"

  ${JENA_ARQ} \
    --data="${tmp_dir}/all.ttl" \
    --query="${tmp_dir}/maturemodule.sq" \
    --results=CSV \
    > ${tmp_dir}/good

  #
  # What should the good file show?
  #
  head ${tmp_dir}/good

  ${SED} -i 's/\r//' ${tmp_dir}/good

  (
    cd ${spec_root:?} || return $?
    rm -f ${tmp_dir}/prodpaths.txt
    touch ${tmp_dir}/prodpaths.txt
    chmod a+w ${tmp_dir}/prodpaths.txt
    ${SED} \
      "s@^@find ${family_product_branch_tag} -name \"@;s/.rdf/.*\"/" \
      ${tmp_dir}/good | \
      tail --lines=+2 | \
      sh > ${tmp_dir}/prodpaths.txt

    echo "prodpaths"
    cat ${tmp_dir}/prodpaths.txt
  )

  return $?
}
