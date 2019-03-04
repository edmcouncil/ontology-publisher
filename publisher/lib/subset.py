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
import pdb
import sys
import string
import sys
import rdflib
from itertools import chain
from rdflib.namespace import SKOS, Namespace, NamespaceManager, RDF, XSD, OWL, RDFS
from rdflib import URIRef, BNode, Literal
import re
from os import scandir, walk, path, makedirs

class TBCGraph(rdflib.Graph):
    def serialize (self, **kwargs):
        onturi=list(self.triples((None, RDF.type, OWL.Ontology)))[0][0]
        dest=kwargs["destination"]
        print ("writing to "+dest)
        relpath="/".join(dest.split("/")[0:-1])
        print ("relpath="+relpath)
        if (relpath!=''):
            makedirs(relpath, exist_ok=True)
        if (kwargs["format"]=="ttl"):
            px="# baseURI: %s\n" % (str(onturi))
        else:
            px=""
        super().serialize(**kwargs)
        with open(dest, 'r', encoding="utf-8",) as original: data = original.read()
        with open(dest, 'w', encoding="utf-8",) as modified: modified.write(px + data)


class Factor():
    def __init__ (self, directory, base):
        self.base=base
        ps=[path.join(root, name) for root, dirs, files in walk(directory) if root!=directory for name in files
            if name.endswith(".rdf") and
            "etc" not in root and
            "git" not in root and
            "About" not in name and
            "All" not in name
            and "Metadata" not in name]

#        print (ps)

        gs=[TBCGraph().parse(path.join(root, name)) for root, dirs, files in walk(directory) if root!=directory for name in files
            if name.endswith(".rdf") and
            "etc" not in root and
            "git" not in root and
            "About" not in name and
            "All" not in name
            and "Metadata" not in name]

        self.out=TBCGraph()
        self.all=TBCGraph()
        for g in gs:
            for n in g.namespace_manager.namespaces():
                self.out.namespace_manager.bind (n[0], n[1])
                self.all.namespace_manager.bind (n[0], n[1])
            for t in g.triples((None, None, None)):
                self.all.add(t)
        print (str(len(list(self.all.triples ((None, None, None)))))+" triples in all")
        self.done=[]

    def save (self):
        self.all.serialize(destination="SAVE/ONTS/full.rdf", encoding="utf-8", format='xml')
        self.all.serialize(destination="SAVE/ONTS/full.ttl", encoding="utf-8", format='turtle')

    def prime (self, seed):
        with open(seed, 'r', encoding="utf-8",) as original:
            s=original.readline()
            while (s!=""):
                if (not s.startswith("#")):
                    self.copy(URIRef(s.strip()), "")
                s=original.readline()

    def copy (self, concept, level):
        if (concept not in self.done):
#            print (level+"copying "+str(concept))
            self.done=self.done+[concept]
            for t in self.all.triples((concept, None, None)):
                self.out.add(t)
                self.copy(t[1], level+" ")
                self.copy(t[2], level+" ")
            for t in self.all.triples((None, OWL.inverseOf, concept)):
                self.out.add(t)
                self.copy(t[0], level+" ")

    def dodump(self):
        self.out.add ((URIRef(self.base), RDF.type, OWL.Ontology))
        uchop=re.sub(r'/$','',self.base)
        self.out.serialize(destination="TEST/"+uchop.split("/")[-1]+".ttl", encoding="utf-8", format='turtle')



f=Factor("C:\\Users\\Dean\\Documents\\fibo", "https://spec.edmcouncil.org/fibo/ontology/")
#f=Factor("C:\\Users\\Dean\\Dropbox\\Dean\\WorkingOntologist\\FIBO\\factor\\SAVE", "https://spec.edmcouncil.org/fibo/ontology/")
# f.save()
f.prime("seeds")
f.dodump()
