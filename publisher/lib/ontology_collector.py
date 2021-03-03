import argparse
import os

from rdflib import Graph, OWL, RDF


def collect_ontologies_in_dev_and_prod(
        ontology_folder_path: str,
        dev_file_path: str,
        prod_file_path: str,
        prod_spec_file_name: str,
        ignored_folder: str):
    print('Collecting Dev and Prod ontologies')

    dev_ontology = Graph()
    prod_ontology = Graph()

    print('Getting external ontologies')

    dev_ontology.parse('http://www.w3.org/2002/07/owl')
    dev_ontology.parse('http://www.w3.org/2000/01/rdf-schema')
    dev_ontology.parse('http://www.w3.org/1999/02/22-rdf-syntax-ns')
    dev_ontology.parse('https://www.omg.org/spec/LCC/Countries/CountryRepresentation/')
    dev_ontology.parse('https://www.omg.org/spec/LCC/Languages/LanguageRepresentation/')

    prod_ontology.parse('http://www.w3.org/2002/07/owl')
    prod_ontology.parse('http://www.w3.org/2000/01/rdf-schema')
    prod_ontology.parse('http://www.w3.org/1999/02/22-rdf-syntax-ns')
    prod_ontology.parse('https://www.omg.org/spec/LCC/Countries/CountryRepresentation/')
    prod_ontology.parse('https://www.omg.org/spec/LCC/Languages/LanguageRepresentation/')

    print('Importing ontologies')

    prod_ontolog_iri_local_parts = \
        __get_prod_ontology_iri_local_parts(prod_spec_folder_path=ontology_folder_path, prod_spec_file_name=prod_spec_file_name)

    for root, dirs, files in os.walk(ontology_folder_path):
        for file in files:
            with open(os.path.join(root, file), "r", encoding='utf8') as fibo_file:
                filename, file_extension = os.path.splitext(file)
                if 'rdf' in file_extension:
                    if not ignored_folder in root:
                        ontology = Graph()
                        print('Importing', file)
                        try:
                            ontology.parse(fibo_file)
                            dev_ontology += ontology
                            ontology_IRIs = ontology.subjects(predicate=RDF.type, object=OWL.Ontology)
                            for ontology_IRI in ontology_IRIs:
                                iri_parts = str(ontology_IRI).split(sep='/')
                                if len(iri_parts) < 2:
                                    continue
                                ontology_IRI_local_part = iri_parts[-2]
                                if ontology_IRI_local_part in prod_ontolog_iri_local_parts:
                                    prod_ontology += ontology
                                    continue
                        except Exception as exception:
                            print('Cannot parse', file, 'because', str(exception.args))
                fibo_file.close()

    dev_ontology.serialize(destination=dev_file_path)
    prod_ontology.serialize(destination=prod_file_path)


def __get_prod_ontology_iri_local_parts(prod_spec_folder_path: str, prod_spec_file_name: str) -> list:
    prod_ontology_iri_local_parts = []
    prod_file = open(os.path.join(prod_spec_folder_path, prod_spec_file_name))
    prod_ontology = Graph()
    prod_ontology.parse(prod_file)

    for subject, predicate, object in prod_ontology:
        if predicate == OWL.imports:
            iri_string = str(object)
            iri_parts = iri_string.split(sep='/')
            prod_ontology_iri_local_parts.append(iri_parts[-2])
    return prod_ontology_iri_local_parts


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Collects all ontologies into DEV and PROD levels')
    parser.add_argument('--input_folder', help='Path to folder with all ontologies', metavar='FOLDER')
    parser.add_argument('--output_dev', help='Path to output dev file', metavar='OUT_DEV')
    parser.add_argument('--output_prod', help='Path to output prod file', metavar='OUT_PROD')
    parser.add_argument('--prod_spec', help='File with PROD spec', metavar='PROD_SPEC')
    parser.add_argument('--ignored', help='Ignored folder', metavar='IGNORED')
    args = parser.parse_args()

    collect_ontologies_in_dev_and_prod(
        ontology_folder_path=args.input_folder,
        dev_file_path=args.output_dev,
        prod_file_path=args.output_prod,
        prod_spec_file_name=args.prod_spec,
        ignored_folder=args.ignored)