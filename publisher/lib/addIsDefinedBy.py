"""
        addIsDefinedBy

        @author Dean Allemang

        Add isDefinedBy links to everything in an ontology

"""
import pdb
import sys
import string
from sys import argv
import sys
import rdflib
from itertools import chain
from rdflib.namespace import SKOS, Namespace, NamespaceManager, RDF, XSD, OWL, RDFS, DC
from rdflib import URIRef, BNode, Literal
import argparse

import re
from os import scandir, walk, path

DCT = Namespace("http://purl.org/dc/terms/")

verbose = False

class Adder():
  
        def __init__(self, args, file):
        
                self.verbose = args.verbose
                self.g = rdflib.Graph().parse(file)

        def addIDB (self):
                onturi=list(self.g.triples((None, RDF.type, OWL.Ontology)))[0][0]
                ts=[t[0] for t in self.g.triples((None, RDF.type, None)) if "edmcouncil" in str(t[0])]
                for t in ts:
                        if (type(t)!=rdflib.BNode):
                                self.g.add((t, RDFS.isDefinedBy, onturi))


                
        def dump (self, file):
                self.g.serialize(destination=file.replace(".rdf", ".ttl"), format='ttl')



if __name__ == "__main__":
  
        parser = argparse.ArgumentParser(description='Adds isDefinedBy to each resource')
        parser.add_argument('--verbose', '-v', help='verbose output', default=False, action='store_true')
        parser.add_argument('--format', '-f', help='Specify either ttl for Turtle or nq for NQuads')
        parser.add_argument('--file', '-p', help='File to work on')
        args = parser.parse_args()

        #
        # TODO: Implement the 4 lines below via argparse
        #
        file = [i.split("--file=")[1] for i in sys.argv if i.startswith("--file=")][0]

  
        f = Adder(args, file)
        f.addIDB()
        f.dump(file)
        
