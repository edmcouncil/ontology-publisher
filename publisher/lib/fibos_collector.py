import argparse
import os

from rdflib import Graph, OWL, RDF


def collect_fibos(fibo_folder_path: str, fibo_dev_file_path: str, fibo_prod_file_path: str):
    print('Collecting FIBO Dev and Prod')

    fibo_dev = Graph()
    fibo_prod = Graph()

    print('Getting external ontologies')

    fibo_dev.parse('http://www.w3.org/2002/07/owl')
    fibo_dev.parse('http://www.w3.org/2000/01/rdf-schema')
    fibo_dev.parse('http://www.w3.org/1999/02/22-rdf-syntax-ns')
    fibo_dev.parse('https://www.omg.org/spec/LCC/Countries/CountryRepresentation/')
    fibo_dev.parse('https://www.omg.org/spec/LCC/Languages/LanguageRepresentation/')

    fibo_prod.parse('http://www.w3.org/2002/07/owl')
    fibo_prod.parse('http://www.w3.org/2000/01/rdf-schema')
    fibo_prod.parse('http://www.w3.org/1999/02/22-rdf-syntax-ns')
    fibo_prod.parse('https://www.omg.org/spec/LCC/Countries/CountryRepresentation/')
    fibo_prod.parse('https://www.omg.org/spec/LCC/Languages/LanguageRepresentation/')

    print('Importing FIBO ontologies')

    fibo_prod_ontolog_iri_local_parts = __get_fibo_prod_ontology_iri_local_parts(fibo_folder_path=fibo_folder_path)
    for root, dirs, files in os.walk(fibo_folder_path):
        for file in files:
            with open(os.path.join(root, file), "r") as fibo_file:
                filename, file_extension = os.path.splitext(file)
                if 'rdf' in file_extension:
                    if not 'etc' in root:
                        ontology = Graph()
                        print('Importing', file)
                        try:
                            ontology.parse(fibo_file)
                            fibo_dev += ontology
                            ontology_IRIs = ontology.subjects(predicate=RDF.type, object=OWL.Ontology)
                            for ontology_IRI in ontology_IRIs:
                                iri_parts = str(ontology_IRI).split(sep='/')
                                if len(iri_parts) < 2:
                                    continue
                                ontology_IRI_local_part = iri_parts[-2]
                                if ontology_IRI_local_part in fibo_prod_ontolog_iri_local_parts:
                                    fibo_prod += ontology
                                    continue
                        except Exception as exception:
                            print('Cannot parse', file, 'because', str(exception.args))
                fibo_file.close()

    fibo_dev.serialize(destination=fibo_dev_file_path)
    fibo_prod.serialize(destination=fibo_prod_file_path)


def __get_fibo_prod_ontology_iri_local_parts(fibo_folder_path: str) -> list:
    fibo_prod_ontolog_iri_local_parts = []
    prod_fibo_file = open(os.path.join(fibo_folder_path, 'AboutFIBOProd.rdf'))
    prod_fibo = Graph()
    prod_fibo.parse(prod_fibo_file)

    for subject, predicate, object in prod_fibo:
        if predicate == OWL.imports:
            iri_string = str(object)
            iri_parts = iri_string.split(sep='/')
            fibo_prod_ontolog_iri_local_parts.append(iri_parts[-2])
    return fibo_prod_ontolog_iri_local_parts


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Collectes all FIBO ontologies into DEV and PROD ontologies')
    parser.add_argument('--input_folder', help='Path to folder with all FIBO ontologies', metavar='FOLDER')
    parser.add_argument('--output_dev', help='Path to output dev file', metavar='OUT_DEV')
    parser.add_argument('--output_prod', help='Path to output prod file', metavar='OUT_PROC')
    args = parser.parse_args()

    collect_fibos(fibo_folder_path=args.input_folder, fibo_dev_file_path=args.output_dev,fibo_prod_file_path=args.output_prod)

# collect_fibos(r'D:\projects\fibo\git\edmc\fibo', '','')