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
import re
import argparse
from os import walk, path, makedirs
from os.path import splitext, isdir, basename
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
    def getGraphList(self, verbose):
        pass
    
class FileOntologySource(OntologySource):
    
    def __init__(self, sourceFile):
        self.sourceFile = sourceFile
    
    def getGraphList(self, verbose):
        
        ret = []
        
        if isdir(self.sourceFile):
            for root, dirs, files in walk(self.sourceFile):
                if root != self.sourceFile and not re.search('etc|git', root):
                    for name in files:
                        fullName = path.join(root, name)
                        g = self.parseFile(fullName)
                        if g:
                            ret.append(g)
        else:
            g = self.parseFile(self.sourceFile)
            if g:
                ret.append(g)
                            
        return ret
    
    def parseFile(self, fileName):
        ret = None
        name = basename(fileName)
        if not re.search('About|All|Metadata', name):
            ff, fe = splitext(name)
            fe = fe.replace('.', '')
            if fe=='rdf' or fe=='ttl' or fe=='nt':
                if fe=='rdf':
                    fe = 'xml'
                ret = TBCGraph().parse(fileName, format=fe)
        return ret
        
        
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
    
    def __init__(self, ontologySource, base, verbose):
        
        self.base = base
        
        gs = ontologySource.getGraphList(verbose)

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

    def save(self, subsetSink, fmt):
        self.all.serialize(subsetSink=subsetSink, fmt=fmt, verbose=self.verbose)

    def prime(self, seedFile=None, seedList=None):
        
        if seedFile is not None:
            seedList = []
            if (self.verbose): print('Reading subset requirements from seeds file at: ' + seedFile)
            with open(seedFile, 'r', encoding=ENCODING,) as original:
                s = original.readline()
                while (s != ""):
                    seedList.append(s)
                    s = original.readline()
                    
        filteredSeedList = []
        for seed in seedList:
            if (not seed.startswith("#")):
                filteredSeedList.append(seed)
        
        if (self.verbose): print('Subsetting ontology for ' + str(len(filteredSeedList)) + ' seeds')
        
        for seed in filteredSeedList:
            self.copy(rdflib.URIRef(seed.strip()), "")     
                  
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

    def writeSubset(self, subsetSink, fmt):
        self.out.add((rdflib.URIRef(self.base), RDF.type, OWL.Ontology))
        self.out.serialize(subsetSink=subsetSink, fmt=fmt, verbose=self.verbose)

def parseArgs():
    argParser = argparse.ArgumentParser()
    argParser.add_argument('ontology', help='Root directory of the ontology to subset, or a single file containing the ontology')
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
    
    f = Factor(ontologySource, args.base, args.verbose)
    
    if seeds is None:
        f.save(destination, args.format)
    else:
        f.prime(seedFile=seeds).writeSubset(destination, args.format)
