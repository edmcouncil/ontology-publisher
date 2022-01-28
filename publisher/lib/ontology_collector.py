import argparse
import os.path
import re
import sys

from rdflib import Graph, OWL, RDF

visited_ontologies = list()
local_ontology_map_regex = re.compile('name="(.+)"\s+uri="(.+)"')
local_ontology_map = dict()
global output_graph


def get_local_ontology_map(ontology_catalog_path: str):
    try:
        ontology_catalog_file = open(ontology_catalog_path, 'r')
        ontology_catalog = ontology_catalog_file.read()
        ontologies = local_ontology_map_regex.findall(string=ontology_catalog)
        for ontology in ontologies:
            local_ontology_map[ontology[0]]=ontology[1][2:]
            v=local_ontology_map
    except Exception as exception:
        print(str(exception))
        sys.exit(-1)
    
    
def collect_ontologies(
        root: str,
        input_ontology_path: str,
        output_graph_path=str(),
        save_output=False):
    global output_graph
    if input_ontology_path in local_ontology_map:
        input_ontology_path = os.path.join(root, local_ontology_map[input_ontology_path])
    if input_ontology_path in visited_ontologies:
        return
    input_ontology = Graph()
    try:
        input_ontology.parse(input_ontology_path)
        visited_ontologies.append(input_ontology_path)
        output_graph += input_ontology
        for subject, predicate, object_value in input_ontology:
            if predicate == OWL.imports:
                collect_ontologies(
                    root=root,
                    input_ontology_path=str(object_value))
    except Exception as exception:
        print(str(exception))
        sys.exit(-1)
    if save_output:
        output_graph.serialize(output_graph_path)
        
        

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Collects all ontologies imported from input ontology')
    parser.add_argument('--root', help='Path to input ontology', metavar='ROOT')
    parser.add_argument('--input_ontology', help='Path to input ontology', metavar='IN_ONT')
    parser.add_argument('--ontology-mapping', help='Path to input ontology', metavar='ONT_MAP')
    parser.add_argument('--output_ontology', help='Path to output dev file', metavar='OUT_ONT')
    args = parser.parse_args()

    get_local_ontology_map(
        ontology_catalog_path=args.ontology_mapping)

    output_graph = Graph()

    collect_ontologies(
        root=args.root,
        input_ontology_path=args.input_ontology,
        output_graph_path=args.output_ontology,
        save_output=True)

    output_graph.close(True)




