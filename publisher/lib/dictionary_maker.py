import argparse
import xlsxwriter
from rdflib import Graph
from rdflib.namespace import OWL


def create_dictionary(ontology_file_path: str, dictionary_file_path: str):
    print('Importing ontologies required by', ontology_file_path)
    ontology = Graph()
    ontology.parse(source=ontology_file_path)
    ontology.parse('http://www.w3.org/2002/07/owl')
    ontology.parse('http://www.w3.org/2000/01/rdf-schema')
    ontology.parse('http://www.w3.org/1999/02/22-rdf-syntax-ns')
    for subject, predicate, object in ontology:
        if predicate == OWL.imports:
            ontology.parse(source=object)


    print('Creating dictionary from ontologies')
    results = ontology.query(
        """
        prefix owl: <http://www.w3.org/2002/07/owl#>
        prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        
        SELECT DISTINCT ?Term ?Type (GROUP_CONCAT(?synonym;SEPARATOR=", ") As ?Synonyms) ?Definition ?GeneratedDefinition ?Example ?Explanation ?Ontology ?Maturity
        WHERE
        {
            ?resource rdf:type/rdfs:subClassOf* ?typeIRI .
            FILTER (CONTAINS(str(?resource), "edmcouncil"))
            FILTER (?typeIRI IN (owl:Class, rdf:Property, owl:NamedIndividual, rdf:Datatype))
            ?resource rdfs:label ?Term .
            FILTER (CONTAINS(LANG(?Term), "en") || LANG(?Term) = "")
            ?typeIRI rdfs:label ?Type .
            OPTIONAL {?resource <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/synonym> ?synonym}
            OPTIONAL {?resource <http://www.w3.org/2004/02/skos/core#definition> ?Definition}
            OPTIONAL {?resource <http://www.w3.org/2004/02/skos/core#example> ?Example}
            OPTIONAL {?resource <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/explanatoryNote> ?Explanation}
            OPTIONAL {
                ?resource rdfs:isDefinedBy ?ontologyIRI . 
                ?ontologyIRI rdfs:label ?Ontology . 
                ?ontologyIRI <https://spec.edmcouncil.org/fibo/ontology/FND/Utilities/AnnotationVocabulary/hasMaturityLevel> ?maturityIRI .
                ?maturityIRI rdfs:label ?Maturity
                    }
        }
        GROUP BY ?Term ?Type ?Definition ?GeneratedDefinition ?Example ?Explanation ?Ontology ?Maturity
        ORDER BY ?Term
        """)

    workbook = xlsxwriter.Workbook('glossary_dev.xlsx')
    worksheet = workbook.add_worksheet('Data Dictionary')
    worksheet.write_row(row=0,col=0, data=['Term', 'Type', 'Synonyms', 'Definition', 'GeneratedDefinition', 'Example', 'Explanation', 'Ontology', 'Maturity'])

    row=1
    for result in results:
        dictionary_row = \
            [
                result['Term'],
                result['Type'],
                result['Synonyms'],
                result['Definition'],
                result['GeneratedDefinition'],
                result['Example'],
                result['Explanation'],
                result['Ontology'],
                result['Maturity']
            ]
        worksheet.write_row(row,col=0,data=dictionary_row)
        row += 1
    workbook.close()

# create_dictionary('AboutFIBODev.rdf','')

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Create a dictionary out of an ontology.')
    parser.add_argument('--ontology', help='Path to <<About>> ontology file', metavar='ONT')
    parser.add_argument('--output', help='Output file path', metavar='FILE')
    args = parser.parse_args()

    create_dictionary(ontology_file_path=args.ontology, dictionary_file_path=args.output)
