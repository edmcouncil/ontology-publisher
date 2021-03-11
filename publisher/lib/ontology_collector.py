import argparse
import os

from rdflib import Graph, OWL, RDF


def collect_ontologies_in_dev_and_prod(
        ontology_folder_path: str,
        dev_file_path: str,
        prod_file_path: str,
        prod_spec_file_name: str,
        external_folders_paths: str):
    print('Collecting Dev and Prod ontologies')

    dev_ontology = Graph()
    prod_ontology = Graph()

    external_iris = []
    for external_folder_path in external_folders_paths.split(":"):
        if ( len(external_folder_path) > 0 ) and os.path.isdir(external_folder_path):
            print('Getting external ontologies from [',external_folder_path,'] directory',sep='')

            for root, dirs, files in os.walk(external_folder_path):
                for file in files:
                    filename, file_extension = os.path.splitext(file)
                    if 'rdf' in file_extension:
                        with open(os.path.join(root, file), "r", encoding='utf8') as external_file:
                            ontology = Graph()
                            try:
                                ontology.parse(external_file)
                                ontology_IRIs = ontology.subjects(predicate=RDF.type, object=OWL.Ontology)
                                for ontology_IRI in ontology_IRIs:
                                    if str(ontology_IRI) not in external_iris:
                                        print(' - importing*:\t IRI=<', ontology_IRI, '>\n\t\tfile=', root, '/', file, sep='')
                                        dev_ontology += ontology
                                        prod_ontology += ontology
                                        external_iris.append(str(ontology_IRI))
                                    else:
                                        print(' -  skipping:\t IRI=<', ontology_IRI, '>\n\t\tfile=', root, '/', file, sep='')
                            except Exception as exception:
                                print('Cannot parse [', root, '/', file, ']: ', str(exception.args), sep='')
                        external_file.close()

    print('Importing ontologies from [',ontology_folder_path,'] directory; Prod ontologies marked as \"importing*\"', sep='')

    prod_ontology_iris = \
        __get_prod_ontology_iris(prod_spec_folder_path=ontology_folder_path, prod_spec_file_name=prod_spec_file_name)

    for root, dirs, files in os.walk(ontology_folder_path):
        for file in files:
            filename, file_extension = os.path.splitext(file)
            if 'rdf' in file_extension:
                with open(os.path.join(root, file), "r", encoding='utf8') as fibo_file:
                    ontology = Graph()
                    try:
                        ontology.parse(fibo_file)
                        ontology_IRIs = ontology.subjects(predicate=RDF.type, object=OWL.Ontology)
                        for ontology_IRI in ontology_IRIs:
                            prod = ''
                            if str(ontology_IRI) in prod_ontology_iris:
                                prod = '*'
                            else:
                                ontology_versionIRIs = ontology.objects(predicate=OWL.versionIRI)
                                for ontology_versionIRI in ontology_versionIRIs:
                                    if str(ontology_versionIRI) in prod_ontology_iris:
                                        prod = '*'
                                        break
                            print(' - importing',prod,':\t IRI=<', ontology_IRI, '>\n\t\tfile=', root, '/', file, sep='')
                            dev_ontology += ontology
                            if prod == '*':
                                prod_ontology += ontology
                    except Exception as exception:
                        print('Cannot parse [', root, '/', file, ']: ', str(exception.args), sep='')
                fibo_file.close()

    dev_ontology.serialize(destination=dev_file_path)
    prod_ontology.serialize(destination=prod_file_path)


def __get_prod_ontology_iris(prod_spec_folder_path: str, prod_spec_file_name: str) -> list:
    prod_ontology_iris = []
    prod_file = open(os.path.join(prod_spec_folder_path, prod_spec_file_name))
    prod_ontology = Graph()
    prod_ontology.parse(prod_file)

    for subject, predicate, object in prod_ontology:
        if predicate == OWL.imports:
            prod_ontology_iris.append(str(object))
    return prod_ontology_iris


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Collects all ontologies into DEV and PROD levels')
    parser.add_argument('--input_folder', help='Path to folder with all ontologies', metavar='FOLDER')
    parser.add_argument('--output_dev', help='Path to output dev file', metavar='OUT_DEV')
    parser.add_argument('--output_prod', help='Path to output prod file', metavar='OUT_PROD')
    parser.add_argument('--prod_spec', help='File with PROD spec', metavar='PROD_SPEC')
    parser.add_argument('--external_folders', help='Paths separated by ":" to folders with external ontologies', metavar='FOLDER[:FOLDER...]')
    args = parser.parse_args()

    collect_ontologies_in_dev_and_prod(
        ontology_folder_path=args.input_folder,
        dev_file_path=args.output_dev,
        prod_file_path=args.output_prod,
        prod_spec_file_name=args.prod_spec,
        external_folders_paths=args.external_folders)
