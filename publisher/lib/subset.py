# MIT License
#
# Copyright (c) 2013-2019 EDM Council, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

"""

"""
import sys
import argparse
from os import walk, path, makedirs
from abc import ABC, abstractmethod

import rdflib
from rdflib.namespace import RDF, OWL

ENCODING = 'utf-8'

class TBCGraph(rdflib.Graph):
    
    def serialize(self, subsetSink, fmt, verbose):
        
        onturi = list(self.triples((None, RDF.type, OWL.Ontology)))[0][0]
        
        data = super().serialize(format=fmt, encoding=ENCODING)
        data = str(data, ENCODING)
        
        subsetSink.saveSubset(data, onturi, fmt, verbose)

class OntologySource(ABC):
    
    @abstractmethod
    def getGraphList(self):
        pass
    
class FileOntologySource(OntologySource):
    
    def __init__(self, directory):
        self.directory = directory
    
    def getGraphList(self):
        return [TBCGraph().parse(path.join(root, name)) for root, dirs, files in walk(self.directory) if root != self.directory for name in files
            if name.endswith(".rdf") and
            "etc" not in root and
            "git" not in root and
            "About" not in name and
            "All" not in name
            and "Metadata" not in name]
        
class SubsetSink(ABC):
    
    @abstractmethod
    def saveSubset(self, subsetData, ontologyURI, fmt, verbose):
        pass
    
class FileSubsetSink(SubsetSink):
    
    def __init__(self, destination):
        self.destination = destination
    
    def saveSubset(self, subsetData, ontologyURI, fmt, verbose):
        
        outStream = sys.stdout
        
        if self.destination is not None:
            if (verbose): print("Writing subset to: " + self.destination)
            relpath = "/".join(self.destination.split("/")[0:-1])
            if (relpath != ''):
                makedirs(relpath, exist_ok=True)
            outStream = open(self.destination, 'w', encoding=ENCODING)
        
        px = ''
        if (fmt == 'turtle'):
            # todo: is this comment necessary?
            px = "# baseURI: %s\n" % (str(ontologyURI))
        
        outStream.write(px + subsetData)

class Factor():
    
    def __init__(self, ontologySource, base, verbose, fmt):
        
        self.base = base
        
        gs = ontologySource.getGraphList()

        self.out = TBCGraph()
        self.all = TBCGraph()
        
        for g in gs:
            for n in g.namespace_manager.namespaces():
                self.out.namespace_manager.bind(n[0], n[1])
                self.all.namespace_manager.bind(n[0], n[1])
            for t in g.triples((None, None, None)):
                self.all.add(t)
                
        if (verbose): print('Found ' + str(len(list(self.all.triples ((None, None, None))))) + " triples in source ontology")
        
        self.done = []
        self.verbose = verbose
        self.fmt = fmt

    def save(self, subsetSink):
        self.all.serialize(subsetSink=subsetSink, fmt=self.fmt, verbose=self.verbose)

    def prime(self, seed):
        if (self.verbose): print('Reading subset requirements from seeds file at: ' + seed)
        with open(seed, 'r', encoding=ENCODING,) as original:
            s = original.readline()
            while (s != ""):
                if (not s.startswith("#")):
                    self.copy(rdflib.URIRef(s.strip()), "")
                s = original.readline()
        return self

    def copy(self, concept, level):
        if (concept not in self.done):
            self.done = self.done + [concept]
            for t in self.all.triples((concept, None, None)):
                self.out.add(t)
                self.copy(t[1], level + " ")
                self.copy(t[2], level + " ")
            for t in self.all.triples((None, OWL.inverseOf, concept)):
                self.out.add(t)
                self.copy(t[0], level + " ")

    def writeSubset(self, subsetSink):
        self.out.add((rdflib.URIRef(self.base), RDF.type, OWL.Ontology))
        self.out.serialize(subsetSink=subsetSink, fmt=self.fmt, verbose=self.verbose)

def parseArgs():
    # todo: perhaps we should infer the format from the OntologySource, unless it's forced with -f?
    argParser = argparse.ArgumentParser()
    argParser.add_argument('ontology', help='Root directory of the ontology to subset')
    argParser.add_argument('base', help='Base URI of subset')
    argParser.add_argument('-f', '--format', help='Subset format (default is ttl/turtle)', default='turtle')
    argParser.add_argument('-s', '--seeds', help='Seeds file; full subset will result if not specified')
    argParser.add_argument('-d', '--destination', help='File into which subset will be written (in turtle format); stdout if not specified')
    argParser.add_argument('-v', '--verbose', dest='verbose', action='store_true', default=False, help='Print dianostic/progress info')
    return argParser.parse_args()

if __name__ == '__main__':
    
    args = parseArgs()
    
    destination = args.destination
    seeds = args.seeds
    
    ontologySource = FileOntologySource(args.ontology)
    destination = FileSubsetSink(destination)
    
    f = Factor(ontologySource, args.base, args.verbose, args.format)
    
    if seeds is None:
        f.save(destination)
    else:
        f.prime(seeds).writeSubset(destination)
