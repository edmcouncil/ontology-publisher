import argparse
import os.path
import re
import sys

from rdflib import Graph, OWL

visited_ontologies = list()
local_ontology_map_regex = re.compile(r'name="(.+)"\s+uri="(.+)"')
local_ontology_map = dict()
global output_graph


def get_local_ontology_map(ontology_catalog_path: str):
    try:
        ontology_catalog_file = open(ontology_catalog_path, 'r')
        ontology_catalog = ontology_catalog_file.read()
        ontologies = local_ontology_map_regex.findall(string=ontology_catalog)
        for ontology in ontologies:
            ontology_iri = ontology[0]
            ontology_local_path = ontology[1]
            local_ontology_map[ontology_iri] = ontology_local_path
    except Exception as exception:
        print('Exception occurred while getting local ontology map', str(exception))
        sys.exit(-1)


def collect_ontologies(
        root: str,
        input_ontology_path: str,
		import_failure: bool,
        output_graph_path=str(),
        save_output=False) -> bool:
    global output_graph
    if input_ontology_path in local_ontology_map:
        input_ontology_path = os.path.join(root, local_ontology_map[input_ontology_path])
    if input_ontology_path in visited_ontologies:
        return import_failure
    input_ontology = Graph()
    try:
        input_ontology.parse(input_ontology_path)
        visited_ontologies.append(input_ontology_path)
        output_graph += input_ontology
        for subject, predicate, object_value in input_ontology:
            if predicate == OWL.imports:
                import_failure = \
                  collect_ontologies(
                    root=root,
                    input_ontology_path=str(object_value),
                    import_failure=import_failure)
    except Exception as exception:
        print('Exception occurred while getting imported ontology', str(exception))
        import_failure = True
    if save_output:
        output_graph.serialize(output_graph_path)
    return import_failure


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Collects all ontologies imported from input ontology')
    parser.add_argument('--root', help='Path to root folder', metavar='ROOT')
    parser.add_argument('--input_ontology', help='Path to input ontology', metavar='IN_ONT')
    parser.add_argument('--ontology-mapping', help='Path to ontology mapping file', metavar='ONT_MAP')
    parser.add_argument('--output_ontology', help='Path to output ontology file', metavar='OUT_ONT')
    args = parser.parse_args()
    
    get_local_ontology_map(
        ontology_catalog_path=args.ontology_mapping)
    
    output_graph = Graph()
    
    import_failure = \
      collect_ontologies(
        root=args.root,
        input_ontology_path=args.input_ontology,
        output_graph_path=args.output_ontology,
        save_output=True,
        import_failure=False)
    
    output_graph.close(True)
    
    if import_failure:
      sys.exit(-1)