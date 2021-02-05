import argparse

import pandas
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
    dictionary_map = dict()
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

    print(str(len(results)))
    count=0
    for result in results:
        dictionary_row = \
            {
                'Term': result['Term'],
                'Type': result['Type'],
                'Synonyms': result['Synonyms'],
                'Definition': result['Definition'],
                'GeneratedDefinition': result['GeneratedDefinition'],
                'Example': result['Example'],
                'Explanation': result['Explanation'],
                'Ontology': result['Ontology'],
                'Maturity': result['Maturity']
            }
        dictionary_map.update({count: dictionary_row})
        count += 1
    print(str(len(dictionary_map)))
    dictionary = pandas.DataFrame.from_dict(data=dictionary_map,orient='index')
    dictionary.to_csv('glossary_dev.csv',index=False)
    dictionary.to_excel('glossary_dev.xlsx',index=False)

# create_dictionary('AboutFIBODev.rdf','')

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Create a dictionary out of an ontology.')
    parser.add_argument('--ontology', help='Path to <<About>> ontology file', metavar='ONT')
    parser.add_argument('--output', help='Output file path', metavar='FILE')
    args = parser.parse_args()

    create_dictionary(ontology_file_path=args.ontology, dictionary_file_path=args.output)
