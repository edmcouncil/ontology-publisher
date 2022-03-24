"""
	trigify.py

	@author Dean Allemang

	It tracks down all the files that are imported by a given file and puts them into a single trig file.
	In this context, the next step it does is to flatten that into a single graph.
	This is a relatively quick way to import just the files mentioned by a single master importing file.

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

class TBCGraph(rdflib.Graph):
  
	def ontologyIRI(self):
		return list(self.subjects(RDF.type, OWL.Ontology))[0]

	def serialize(self, **kwargs):
		dest = kwargs["destination"]
		px = "# baseURI: %s\n" % (str(self.ontologyIRI()))
		super().serialize(**kwargs)
		with open(dest, 'r', encoding = "utf-8", ) as original: data = original.read()
		with open(dest, 'w', encoding = "utf-8", ) as modified: modified.write(px + data)


class Trigger():
  
	def __init__(self, args, directories, tops):
	
		self.verbose = args.verbose
		self.noimports = args.noimports
		gs = self.__loadGraphs(directories)
		self.__createDictionary(gs)
		self.undefined = []
		self.included = dict([])
		for i in tops:
			self.__tagImports(URIRef(i), 0)
		if self.verbose:
			self.__countTags()
  
	def __loadGraphs(self, directories):
		"""
			Load all the ontology files in the given directories, store each
			in a TBCGraph and store all TBCGraphs in the gs array.
		"""
		gs = []
		for directory in directories:
			gs.extend([
				TBCGraph().parse(path.join(root, name))
					for root, dirs, files in walk(directory)
						for name in files
							if name.endswith(".rdf") and
								("etc" not in root or ("etc" in root and "imports" in root)) and
								"git" not in root and
								"All" not in name and
								"ont-policy.rdf" not in name
			])
		return gs
  
	def __getOntologyIRIsInGraph(self, g):
		return list(g.subjects(RDF.type, OWL.Ontology))

	def __getVersionIRIsInGraph(self, g):
		return list(g.objects(None, OWL.versionIRI))

	def __createDictionary(self, gs):
		"""
			Create a dictionary, self.gix, that has all the ontology IRIs and ontology
			version IRIs as keys where their value is a set containing all the graphs
			they appear in.
		"""
		self.gix = dict()
		if self.verbose:
			print("All graphs:")
		for g in gs:
			if self.verbose:
				print("\ngraph {}".format(g.identifier))
			ontologyIRIs = self.__getOntologyIRIsInGraph(g)
			for ontologyIRI in ontologyIRIs:
				if self.verbose:
					print(" - ontology IRI {}".format(ontologyIRI))
				self.gix.setdefault(ontologyIRI, set()).add(g)
			if self.verbose:
				for label in self.__getLabelsOf(g, ontologyIRIs):
					print(" - label [{}]".format(label))
				for abstract in self.__getAbstractsOf(g, ontologyIRIs):
					print(" - abstract [{}]".format(abstract))

			versionIRIs = self.__getVersionIRIsInGraph(g)
			for versionIRI in versionIRIs:
				if self.verbose:
					print(" - version IRI  {}".format(versionIRI))
				self.gix.setdefault(versionIRI, set()).add(g)
		for k, v in self.gix.items():
			if (len(v)>1):
				print ("key {} has more than one value. This will cause confusion.".format(k))
		if self.verbose:
			self.__printDict()

	def __printDict(self):

		print("\nCreated dictionary:")
		for k, v in self.gix.items():
			for g in v:
				print("{} -> {}".format(k, g.identifier))
		print("End of dict")

	def __tagImports(self, url, level):
		""" 
			Not sure yet what's happening here
		"""
		if self.verbose:
			print("Tag {} level {}".format(url, level))
		if (url not in self.included.keys()):
			self.included[url] = True
			for i in self.__getImports(url):
				self.__tagImports(i, level + 1)

	def __getImports(self, ontologyIRI):
		"""
			Return the import IRIs for the given ontology
		"""
		try:
			g = self.gix[ontologyIRI]
			ice = [t[2] for gx in g for t in gx.triples((None, OWL.imports, None))]
		except:
			self.undefined.append(ontologyIRI)
			print ("getImports failed on {}".format(ontologyIRI))
			ice = []
		return (ice)

	def __countTags(self):
		print("%d ontologies were tagged" %
		      len([key for key in self.included.keys() if self.included[key]]))

	def __getLabelsOf(self, g, subjects):
		"""
			Get all the rdfs:label values for the given subjects
		"""
		return list([
			label for subject in subjects for label in g.objects(subject, RDFS.label)
		])

	def __getAbstractsOf(self, g, subjects):
		"""
			Get all the dct:abstract values for the given subjects
		"""
		return list([
			abstract for subject in subjects for abstract in g.objects(subject, DCT.abstract)
		])
		
	def __fixgraph(self, g):
		"""
			JG>Dean, not sure what happens here, trying to understand, should it try to get the
			rdfs:label or dct:abstract from the About ontology or from the actual ontology?

                        JG: Nothing is happening here.  It should be deleted.  
		"""
		print(" - fix graph {}".format(g.identifier))
		print("   - ontology IRIs {}".format([
			ontologyIRI.n3() for ontologyIRI in self.__getOntologyIRIsInGraph(g)
		]))
		labels = self.__getLabelsOf(g, self.__getOntologyIRIsInGraph(g))
		if not labels:
			labels = ["No label"]
		abstracts = self.__getAbstractsOf(g, self.__getOntologyIRIsInGraph(g))
		if not abstracts:
			abstracts = ["No abstract"]
		for ontologyIRI in self.__getOntologyIRIsInGraph(g):
			print("   - ontology IRI {}".format(ontologyIRI))
			for label in labels:
				g.add((ontologyIRI, DC.title, Literal(label)))
				print("     - label {}".format(label))
			for abstract in abstracts:
				g.add((ontologyIRI, DC.description, Literal(abstract)))
				print("     - abstract {}".format(abstract))

	def dumpNQ(self, out):
		cg = rdflib.graph.ConjunctiveGraph()
		print("Exporting to NQ file {}".format(out))
		for key in self.gix.keys():
			if key in self.included.keys():
				print(" - Processing key {}".format(key))
				graphs = self.gix[key]
				for graph in graphs:
#					self.__fixgraph(graph)
					for prefix, namespace in NamespaceManager(graph).namespaces():
						NamespaceManager(cg).bind(prefix, namespace)
					for trip in graph.triples((None, None, None)):
						cg.add((trip[0], trip[1], trip[2], graph))
			else:
				print(" - Not included: {}".format(key))
		NamespaceManager(cg).bind("dc", "http://purl.org/dc/elements/1.1/")
		cg.serialize(destination = out, format = 'trig')
  
	def dumpTTL(self, out):
		cg = TBCGraph()
		print("Exporting to turtle file {}".format(out))
		for key in self.gix.keys():
			if key in self.included.keys():
				print(" - Processing key {}".format(key))
				graphs = self.gix[key]
				for graph in graphs:
#					self.__fixgraph(graph)
					for prefix, namespace in NamespaceManager(graph).namespaces():
						NamespaceManager(cg).bind(prefix, namespace)
					for trip in graph.triples((None, None, None)):
						if not(self.noimports and trip[1]==OWL.imports):
						        cg.add((trip[0], trip[1], trip[2]))
			else:
				print(" - Not included: {}".format(key))
		cg.add((rdflib.URIRef("http://example.org/output"), RDF.type, OWL.Ontology))
		NamespaceManager(cg).bind("dc", "http://purl.org/dc/elements/1.1/")
		cg.serialize(destination = out, format = 'ttl')

if __name__ == "__main__":
  
	parser = argparse.ArgumentParser(description='Flattens some ontologies into one file.')
	parser.add_argument('--verbose', '-v', help='verbose output', default=False, action='store_true')
	parser.add_argument('--format', '-f', help='Specify either ttl for Turtle or nq for NQuads')
	parser.add_argument('--noimports', '-ni', help='Suppress imports triples in output. Default is to include them.', default=False, action='store_true')
	parser.add_argument(
		'--dir', help='The root directory where to find ontology files', metavar='DIR')
	parser.add_argument(
		'--top', help='???')
	parser.add_argument(
		'--output', help='???', metavar='FILE')
	args = parser.parse_args()

	verbose = '--verbose' in args
	print("verbose is {}\n{}".format(args.verbose, args))

	#
	# TODO: Implement the 4 lines below via argparse
	#
	dirs = [i.split("--dir=")[1] for i in sys.argv if i.startswith("--dir=")]
	tops = [i.split("--top=")[1] for i in sys.argv if i.startswith("--top=")]
	outfile = [i.split("--output=")[1] for i in sys.argv if i.startswith("--output=")][0]
	format = [i.split("--format=")[1] for i in sys.argv if i.startswith("--format=")][0]
  
	f = Trigger(args, dirs, tops)
  
	if format == "ttl":
		f.dumpTTL(outfile)
	else:
		f.dumpNQ(outfile)
