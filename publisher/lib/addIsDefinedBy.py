"""
        addIsDefinedBy

        @author Dean Allemang

        Add isDefinedBy links to everything in an ontology

        3/22/19  Also add a comment to annotate the qname of every resource

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
VANN = Namespace("http://purl.org/vocab/vann/")
SM = Namespace("http://www.omg.org/techprocess/ab/SpecificationMetadata/")

verbose = False

def localname (resource):
        return str(resource).split("/")[-1].split("#")[-1]

class Adder():
  
        def __init__(self, args, file):
        
                self.verbose = args.verbose
                self.g = rdflib.Graph().parse(file)

        def addIDB (self):
                onturi=list(self.g.triples((None, RDF.type, OWL.Ontology)))[0][0]
                ontstring=str(onturi)
                ts=[t[0] for t in self.g.triples((None, RDF.type, None)) if str(t[0]).startswith(ontstring)]  
                for t in ts:
                        if (type(t)!=rdflib.BNode):
                                self.g.add((t, RDFS.isDefinedBy, onturi))

        def addQName (self):
                onturi=list(self.g.triples((None, RDF.type, OWL.Ontology)))[0][0]
                ontstring=str(onturi)
                prefix=(([str(t[2]) for t in self.g.triples((onturi, VANN.preferredNamespacePrefix, None))] +
                         [str(t[2]) for t in self.g.triples((onturi, SM.fileAbbreviation, None))] +
                         ["NONE"]) [0]) + ":"
                ts=[t[0] for t in self.g.triples((None, RDF.type, None)) if str(t[0]).startswith(ontstring)]
                for t in ts:
                        if (type(t)!=rdflib.BNode):
                                self.g.add((t, RDFS.comment, Literal("<b>QName: </b>"+prefix+localname(t))))


                
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
        f.addQName()
        f.dump(file)
        
