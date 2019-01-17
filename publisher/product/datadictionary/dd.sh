#!/bin/bash

inputDirectory="../../../../fibo"


if [ "$1" = "yes" ] ;
then

cat > "echo.sq" <<EOF


CONSTRUCT {?s ?p ?o}
WHERE {?s ?p ?o }

EOF



arq  $(find $sourceRoot/be $sourceRoot/bp $sourceRoot/cae $sourceRoot/civ $sourceRoot/der $sourceRoot/fbc $sourceRoot/fnd $sourceRoot/ind $sourceRoot/loan $sourceRoot/md $sourceRoot/sec -name "*.rdf" | ${SED} "s/^/--data=/") --data=AllProd.ttl --query=echo.sq --results=TTL> combined.ttl

echo "finished combining"




arq --data=combined.ttl --query=pseudorange.sq > pr.ttl


cat > "con1.sq" <<EOF
PREFIX av: <https://spec.edmcouncil.org/fibo/FND/Utilities/AnnotationVocabulary/>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 

SELECT DISTINCT ?c
WHERE {?x av:forCM true . 
?x rdfs:subClassOf* ?c  .
FILTER (ISIRI (?c))
}

EOF



arq --data=combined.ttl --query=con1.sq --results=TSV > CONCEPTS

#arq --data=combined.ttl --data=AllProd.ttl --query=pseudorange1.sq > pr1.ttl
#${SED} -i "s/@en//g" pr1.ttl



cat > "ss.sq" << EOF

PREFIX afn: <http://jena.apache.org/ARQ/function#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
prefix skos: <http://www.w3.org/2004/02/skos/core#> 
prefix edm: <http://www.edmcouncil.org/temp#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX av: <https://spec.edmcouncil.org/fibo/FND/Utilities/AnnotationVocabulary/>


#CONSTRUCT {[ a edm:Row; edm:table ?table; edm:definition ?definition; edm:field ?field; edm:description ?description; edm:type ?type; edm:class ?class; edm:next ?r1]}
SELECT ?class ?table ?definition ?field ?description ?type ?r1
WHERE {
?class a owl:Class .
FILTER (ISIRI (?class))
FIlTER (REGEX (xsd:string (?class), "edmcouncil"))
?class rdfs:subClassOf* ?base1 .
?b1 edm:pseudodomain ?base1; a edm:PR ; edm:p ?p ; edm:pseudorange ?r1  .
#?p av:forDD "true"^^xsd:boolean .
FILTER NOT EXISTS {?class rdfs:subClassOf* ?base2 .
#                   FILTER (?base2 != ?base1)
                   ?b2 a edm:PR ; edm:p ?p ; edm:pseudorange ?r2 ; edm:pseudodomain ?base2 .
		   ?r2 rdfs:subClassOf+ ?r1 }


?p rdfs:label ?field .
OPTIONAL {?p  skos:definition ?dx}
BIND (COALESCE (?dx, "(none)") AS ?description )
?r1 rdfs:label ?type .
?class rdfs:label ?table
OPTIONAL {?class skos:definition  ?dy }
BIND ( COALESCE (?dy, "(none)") AS ?definition )

} 


EOF

arq --data=combined.ttl --data=pr.ttl --data=AllProd.ttl  --query=ss.sq --results=TSV | ${SED} 's/"@../"/g' > ssx.txt
sort -u ssx.txt > ss.txt


### Store all this into a TDB so that we never haver to parse again

#rm -r TEMP
#tdbloader2 --loc TEMP ss.ttl

###


fi

echo "finished pseudorange"

rm -r outputs
mkdir outputs 
echo "" > output.tsv

cp CONCEPTS DONE



function localdd () {

if ${GREP} -q "$1" DONE ;
then
     echo "I've seen it before!"
else
echo "$1" >> DONE


${GREP}  "^$1" ss.txt | \
${SED} "s/^[^\t]*\t//; s/\t[^\t]*$//; 2,\$s/^[^\t]*\t[^\t]*\t/\t\"\"\t/" >> output.tsv

echo "Finished tsv sed for $1"


#tdbquery --loc=TEMP  --query=temp2.sq --results=TSV   > next
${GREP} "^$1" ss.txt | ${SED} 's/^.*\t//'  |  while read uri ; do
  localdd "$(echo "${uri}" | ${SED} 's/\r//')"
done


fi
}


function dumpdd () {

echo "$1"
t=${1##*/}
fname=${t%>*}
echo $fname
rm -f outputs/$fname.*

echo "" > output.tsv

cp CONCEPTS DONE

localdd $1


cat > outputs/$fname.csv <<EOF
Table,Definition,Field,Field Definition,Type
EOF

${SED} 's/"\t"/","/g; s/^\t"/,"/' output.tsv > $outputs/fname.csv


cat > outputs/$fname.xls <<EOF
<table border=1>
<tr><th  bgcolor="goldenrod">Table</th><th  bgcolor="goldenrod">Definition</th><th  bgcolor="goldenrod">Field</th><th  bgcolor="goldenrod">Field Definition</th><th  bgcolor="goldenrod">Type</th></tr>
EOF
tail -n +2 output.tsv | ${SED} 's!"\t"!</td><td valign="top">!g; s!^"!<td valign="top">!; s!^\t"!<td/><td valign="top">!; s!"$!</td>!g; s!^!<tr>!; s!$!</tr>!'  >> outputs/$fname.xls
cat >>$outputs/fname.xls <<EOF
</table>
EOF
${SED} -i '4,${s/<td/<td bgcolor="azure"/g;n}' outputs/$fname.xls
}




cat > "dumps.sq" <<EOF

prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
SELECT ?c
WHERE {
?x <https://spec.edmcouncil.org/fibo/FND/Utilities/AnnotationVocabulary/dumpable> true .
#?c rdfs:subClassOf* ?x . 
BIND (?x AS ?c)
}

EOF

arq  --data=combined.ttl --query=dumps.sq  --results=TSV> dumps


tail -n +2 dumps | while read class ; do
    dumpdd $class
done
