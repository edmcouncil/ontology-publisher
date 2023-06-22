import argparse
import logging

from rdflib import Graph, RDF, OWL, RDFS, SH, Namespace, XSD
from rdflib.term import Node, BNode, URIRef, Literal


class RDFSHACLResource:
    rdf_shacl_identity_registry = dict()
    base_namespace = None
    ontology_graph = Graph()
    
    @staticmethod
    def get_qname(iri: URIRef):
        proper_qname = RDFSHACLResource.ontology_graph.qname(iri)
        if len(proper_qname) > 0:
            return proper_qname
        return iri
    
    def __init__(self, owl_construct_type: str, iri: URIRef = None):
        self.owl_construct_type = owl_construct_type
        self.iri = iri
        RDFSHACLResource.rdf_shacl_identity_registry[iri] = self
    
    def __eq__(self, other):
        if not isinstance(other, RDFSHACLResource):
            return False
        if self.iri is not None or other.iri is not None:
            return self.iri == other.iri
        return self.owl_construct_type == self.owl_construct_type
    
    def __get_hashable_attributes(self) -> list:
        return [self.owl_construct_type]
    
    def __hash__(self):
        if self.iri is not None:
            return self.iri.__hash__()
        hashable_list = self.__get_hashable_attributes()
        return str(hashable_list).__hash__()


class RDFSHACLList(RDFSHACLResource):
    def __init__(self, owl_construct_type: str, listed_resources: list):
        super().__init__(owl_construct_type=owl_construct_type)
        self.listed_resources = listed_resources


class RDFSSHACLClass(RDFSHACLResource):
    def __init__(self, iri: URIRef):
        super().__init__(owl_construct_type=OWL.Class, iri=iri)
        self.super_classes = set()
    
    def __eq__(self, other):
        if not isinstance(other, RDFSSHACLClass):
            return False
        if self.iri is not None or other.iri is not None:
            return self.iri == other.iri
    
    def __hash__(self):
        if self.iri is not None:
            return self.iri.__hash__()
        return str(self.iri).__hash__()


class OWLSHACLClass(RDFSSHACLClass):
    def __init__(self, iri: URIRef):
        super().__init__(iri=iri)


class OWLSHACLDatatype(RDFSSHACLClass):
    def __init__(self, iri: URIRef):
        super().__init__(iri=iri)


class OWLSHACLLiteral(RDFSSHACLClass):
    def __init__(self, iri: URIRef):
        super().__init__(iri=iri)


class OWLNamedIndividualSHACL(RDFSHACLResource):
    def __init__(self, iri: URIRef, types: set = None):
        super().__init__(owl_construct_type=OWL.Class, iri=iri)
        self.types = types
    
    def __eq__(self, other):
        if not isinstance(other, OWLNamedIndividualSHACL):
            return False
        return self.iri == other.iri
    
    def __hash__(self):
        return str(self.iri).__hash__()


class OWLSHACLProperty(RDFSHACLResource):
    def __init__(self, iri: URIRef, super_properties: set = None):
        super().__init__(owl_construct_type=OWL.Class, iri=iri)
        self.super_properties = super_properties
    
    def __eq__(self, other):
        if not isinstance(other, RDFSSHACLClass):
            return False
        return self.iri == other.iri
    
    def __hash__(self):
        return str(self.iri).__hash__()


class OWLSHACLRestriction(RDFSHACLResource):
    restriction_registry = dict()
    
    def __init__(self, restriction_type: str, restricting_property: OWLSHACLProperty,
                 restricting_class: RDFSSHACLClass, restricting_cardinality: int):
        super().__init__(owl_construct_type=OWL.Restriction, iri=None)
        self.restriction_type = restriction_type
        self.restricting_property = restricting_property
        self.restricting_class = restricting_class
        self.restricting_cardinality = restricting_cardinality
        OWLSHACLRestriction.restriction_registry[
            restriction_type, restricting_property, restricting_class, restricting_cardinality] = self
    
    def __get_hashable_attributes(self) -> list:
        return [self.restriction_type, self.restricting_property, self.restricting_class, self.restricting_cardinality]
    
    def __eq__(self, other):
        return self.__hash__() == other.__hash__()
    
    def __hash__(self):
        return str(self.__get_hashable_attributes()).__hash__()


class SHACLShape:
    identity_registry = dict()
    shacl_graph = Graph()
    
    def __init__(self, rdf_shacl_resource: RDFSHACLResource):
        self.rdf_shacl_resource = rdf_shacl_resource
        SHACLShape.identity_registry[rdf_shacl_resource] = self
    
    def serialise(self) -> str:
        pass
    
    @staticmethod
    def get_iri_local_fragment(iri: URIRef) -> str:
        if len(iri.fragment) > 0:
            return iri.fragment
        else:
            return iri.split(sep='/')[-1]
    
    def get_iri_namespace(self, iri: URIRef) -> str:
        return iri.replace(self.get_iri_local_fragment(iri=iri), '')


class SHACLPropertyShape(SHACLShape):
    serialisation_register = dict()
    
    def __init__(self, owl_shacl_restriction: OWLSHACLRestriction):
        super().__init__(rdf_shacl_resource=owl_shacl_restriction)
        self.owl_shacl_restriction = owl_shacl_restriction
    
    def serialise(self):
        shacl_shape_id = \
            RDFSHACLResource.base_namespace + \
            self.get_iri_local_fragment(iri=self.rdf_shacl_resource.restriction_type) + \
            self.get_iri_local_fragment(iri=self.rdf_shacl_resource.restricting_property.iri) + \
            self.get_iri_local_fragment(self.rdf_shacl_resource.restricting_class.iri) + \
            SH.PropertyShape.fragment
        shacl_shape = URIRef(shacl_shape_id)
        
        self.shacl_graph.add((shacl_shape, RDF.type, SH.PropertyShape))
        self.shacl_graph.add((shacl_shape, SH.path, self.owl_shacl_restriction.restricting_property.iri))
        if isinstance(self.owl_shacl_restriction.restricting_class, OWLSHACLClass):
            self.shacl_graph.add((shacl_shape, SH.targetClass, self.owl_shacl_restriction.restricting_class.iri))
        if isinstance(self.owl_shacl_restriction.restricting_class, OWLSHACLDatatype):
            self.shacl_graph.add((shacl_shape, SH.datatype, self.owl_shacl_restriction.restricting_class.iri))
        if isinstance(self.owl_shacl_restriction.restricting_class, OWLSHACLLiteral):
            self.shacl_graph.add((shacl_shape, SH.nodeKind, SH.Literal))
        if self.owl_shacl_restriction.restriction_type == OWL.someValuesFrom:
            self.shacl_graph.add(
                (shacl_shape, SH.minCount, Literal(self.owl_shacl_restriction.restricting_cardinality)))
        
        SHACLPropertyShape.serialisation_register[self] = shacl_shape


class SHACLNodeShape(SHACLShape):
    def __init__(self, owl_shacl_class: RDFSSHACLClass):
        super().__init__(rdf_shacl_resource=owl_shacl_class)
    
    def serialise(self):
        relevant_shacl_property_shapes = self.__get_relevant_property_shapes()
        if len(relevant_shacl_property_shapes) == 0:
            return
        
        shacl_shape_id = self.rdf_shacl_resource.iri + SH.NodeShape.fragment
        shacl_shape = URIRef(shacl_shape_id)
        
        self.shacl_graph.add((shacl_shape, RDF.type, SH.NodeShape))
        self.shacl_graph.add((shacl_shape, SH.targetClass, self.rdf_shacl_resource.iri))
        
        for relevant_restriction in relevant_shacl_property_shapes:
            self.shacl_graph.add(
                (shacl_shape, SH.property, SHACLPropertyShape.serialisation_register[relevant_restriction]))
    
    def __get_relevant_property_shapes(self) -> set:
        relevant_shacl_property_shapes = set()
        
        unfiltered_restrictions = set()
        for owl_shacl_class in self.rdf_shacl_resource.super_classes:
            if isinstance(owl_shacl_class, OWLSHACLRestriction):
                unfiltered_restrictions.add(owl_shacl_class)
        filtered_out_restrictions = self.filter_out_owl_restrictions(unfiltered_restrictions=unfiltered_restrictions)
        
        for filtered_out_restriction in filtered_out_restrictions:
            shacl_property_shape = SHACLShape.identity_registry[filtered_out_restriction]
            if shacl_property_shape in SHACLPropertyShape.serialisation_register:
                relevant_shacl_property_shapes.add(shacl_property_shape)
        return relevant_shacl_property_shapes
    
    @staticmethod
    def filter_out_owl_restrictions(unfiltered_restrictions: set) -> set:
        filtered_out_restrictions = unfiltered_restrictions.copy()
        for owl_shacl_class_1 in unfiltered_restrictions:
            restricting_property_1 = owl_shacl_class_1.restricting_property.iri
            restricting_class_1 = owl_shacl_class_1.restricting_class.iri
            for owl_shacl_class_2 in unfiltered_restrictions:
                restricting_property_2 = owl_shacl_class_2.restricting_property.iri
                restricting_class_2 = owl_shacl_class_2.restricting_class.iri
                if restricting_class_1 == restricting_class_2 and restricting_property_1 == restricting_property_2:
                    continue
                restricting_property_2_parents = \
                    set(RDFSHACLResource.ontology_graph.transitive_objects(
                        subject=restricting_property_2,
                        predicate=RDFS.subPropertyOf))
                # restricting_property_2_parents.add(restricting_property_2)
                restricting_class_2_parents = \
                    set(RDFSHACLResource.ontology_graph.transitive_objects(
                        subject=restricting_class_2,
                        predicate=RDFS.subClassOf))
                # restricting_class_2_parents.add(restricting_class_2)
                if owl_shacl_class_1.restriction_type == OWL.someValuesFrom and owl_shacl_class_2.restriction_type == OWL.someValuesFrom:
                    if restricting_property_1 in restricting_property_2_parents and restricting_class_1 in restricting_class_2_parents:
                        if owl_shacl_class_2 in filtered_out_restrictions:
                            filtered_out_restrictions.remove(owl_shacl_class_1)
        
        if len(filtered_out_restrictions) == len(unfiltered_restrictions):
            return filtered_out_restrictions
        
        return SHACLNodeShape.filter_out_owl_restrictions(unfiltered_restrictions=filtered_out_restrictions)
        
        
    
    def __str__(self):
        return self.rdf_shacl_resource.__str__()
    
    def __repr__(self):
        return self.__str__()


def __process_node(node: Node, ontology_graph: Graph) -> RDFSHACLResource:
    if isinstance(node, BNode):
        return __process_bnode(bnode=node, ontology_graph=ontology_graph)
    if isinstance(node, URIRef):
        return __process_iri(iri=node, ontology_graph=ontology_graph)
    v = 0


def __process_bnode(bnode: BNode, ontology_graph: Graph) -> RDFSHACLResource:
    if (bnode, RDF.type, OWL.Restriction) in ontology_graph:
        rdf_shacl_resource = __process_owl_restriction(owl_restriction=bnode, ontology_graph=ontology_graph)
        return rdf_shacl_resource
    
    typed_list = __try_to_cast_bnode_as_typed_list(bnode=bnode, ontology_graph=ontology_graph)
    
    if typed_list:
        if typed_list[0] == OWL.complementOf:
            owl_constructs = [__process_node(node=typed_list[1], ontology_graph=ontology_graph)]
        else:
            owl_constructs = __get_listed_resources(rdf_list_object=typed_list[1], ontology=ontology_graph,
                                                    rdf_list=list())
        if typed_list[0] == OWL.unionOf:
            return RDFSHACLList(owl_construct_type=OWL.unionOf, listed_resources=owl_constructs)
        if typed_list[0] == OWL.intersectionOf:
            return RDFSHACLList(owl_construct_type=OWL.intersectionOf, listed_resources=owl_constructs)
        if typed_list[0] == OWL.complementOf:
            return RDFSHACLList(owl_construct_type=OWL.complementOf, listed_resources=owl_constructs)
        if typed_list[0] == OWL.oneOf:
            RDFSHACLList(owl_construct_type=OWL.oneOf, listed_resources=owl_constructs)
    
    # logging.warning(msg='Something is wrong with the list: ' + str(typed_list))


def __process_iri(iri: URIRef, ontology_graph: Graph) -> RDFSHACLResource:
    owl_shacl_resource = None
    
    if iri in RDFSHACLResource.rdf_shacl_identity_registry:
        return RDFSHACLResource.rdf_shacl_identity_registry[iri]
    
    owl_type = RDFS.Resource
    owl_parents = list()
    
    if iri in XSD:
        owl_type = RDFS.Datatype
        owl_shacl_resource = OWLSHACLDatatype(iri=iri)
    
    elif iri is RDFS.Literal:
        owl_type = RDFS.Literal
        owl_shacl_resource = OWLSHACLLiteral(iri=iri)
    else:
        types = set(ontology_graph.objects(subject=iri, predicate=RDF.type))
        if OWL.Class in types:
            owl_type = OWL.Class
            owl_parents = list(ontology_graph.transitive_objects(subject=iri, predicate=RDFS.subClassOf))
            owl_shacl_resource = OWLSHACLClass(iri=iri)
        if OWL.NamedIndividual in types:
            owl_type = OWL.NamedIndividual
            owl_parents = list(ontology_graph.objects(subject=iri, predicate=RDF.type))
            owl_shacl_resource = OWLNamedIndividualSHACL(iri=iri)
        if OWL.ObjectProperty in types:
            owl_type = OWL.ObjectProperty
            owl_parents = list(ontology_graph.transitive_objects(subject=iri, predicate=RDFS.subPropertyOf))
            owl_shacl_resource = OWLSHACLProperty(iri=iri)
        if OWL.DatatypeProperty in types:
            owl_type = OWL.DatatypeProperty
            owl_parents = list(ontology_graph.transitive_objects(subject=iri, predicate=RDFS.subPropertyOf))
            owl_shacl_resource = OWLSHACLProperty(iri=iri)
    
    if iri in owl_parents:
        owl_parents.remove(iri)
    
    owl_shacl_parents = set()
    for owl_parent in owl_parents:
        parent = __process_node(node=owl_parent, ontology_graph=ontology_graph)
        if parent is not None:
            owl_shacl_parents.add(parent)
    
    if owl_type == OWL.Class:
        if isinstance(iri, URIRef):
            owl_shacl_resource.super_classes = owl_shacl_parents
    
    if owl_type == OWL.ObjectProperty or owl_type == OWL.DatatypeProperty:
        owl_shacl_resource.super_properties = owl_shacl_parents
    
    if owl_type == OWL.NamedIndividual:
        owl_shacl_resource.types = owl_shacl_parents
    
    return owl_shacl_resource


def __process_owl_restriction(owl_restriction: Node, ontology_graph: Graph) -> RDFSHACLResource:
    owl_properties = list(ontology_graph.objects(subject=owl_restriction, predicate=OWL.onProperty))
    owl_property = owl_properties[0]
    owl_someValuesFrom = list(ontology_graph.objects(subject=owl_restriction, predicate=OWL.someValuesFrom))
    
    restricting_owl_shacl_property = __process_node(node=owl_property, ontology_graph=ontology_graph)
    
    if len(owl_someValuesFrom) > 0:
        restricting_node = owl_someValuesFrom[0]
        restricting_owl_shacl_class = __process_node(node=restricting_node, ontology_graph=ontology_graph)
        if restricting_owl_shacl_class and restricting_owl_shacl_property:
            if restricting_owl_shacl_class.iri is not None:
                owl_shacl_restriction = \
                    OWLSHACLRestriction(
                        restriction_type=OWL.someValuesFrom,
                        restricting_property=restricting_owl_shacl_property,
                        restricting_class=restricting_owl_shacl_class,
                        restricting_cardinality=1)
                return owl_shacl_restriction
    
    # logging.warning(msg='Cannot get formula from a restriction')


def __try_to_cast_bnode_as_typed_list(bnode: BNode, ontology_graph: Graph) -> tuple:
    owl_unions = list(ontology_graph.objects(subject=bnode, predicate=OWL.unionOf))
    if len(owl_unions) > 0:
        return OWL.unionOf, owl_unions[0]
    
    owl_intersections = list(ontology_graph.objects(subject=bnode, predicate=OWL.intersectionOf))
    if len(owl_intersections) > 0:
        return OWL.intersectionOf, owl_intersections[0]
    
    owl_complements = list(ontology_graph.objects(subject=bnode, predicate=OWL.complementOf))
    if len(owl_complements) > 0:
        return OWL.complementOf, owl_complements[0]
    
    owl_oneOfs = list(ontology_graph.objects(subject=bnode, predicate=OWL.oneOf))
    if len(owl_oneOfs) > 0:
        return OWL.oneOf, owl_oneOfs[0]


def __get_listed_resources(rdf_list_object: Node, ontology: Graph, rdf_list: list) -> list:
    first_items_in_rdf_list = list(ontology.objects(subject=rdf_list_object, predicate=RDF.first))
    if len(first_items_in_rdf_list) == 0:
        return rdf_list
    resource = __process_node(node=first_items_in_rdf_list[0], ontology_graph=ontology)
    rdf_list.append(resource)
    rest_items_in_rdf_list = list(ontology.objects(subject=rdf_list_object, predicate=RDF.rest))
    rdf_list = __get_listed_resources(rdf_list_object=rest_items_in_rdf_list[0], ontology=ontology, rdf_list=rdf_list)
    return rdf_list


def __collect_owl_constructs(ontology_graph: Graph):
    owl_classes = ontology_graph.subjects(predicate=RDF.type, object=OWL.Class)
    for owl_class in owl_classes:
        if isinstance(owl_class, URIRef):
            __process_iri(iri=owl_class, ontology_graph=ontology_graph)


def __populate_shacl_shape_objects():
    for owl_shacl_restriction in OWLSHACLRestriction.restriction_registry.values():
        SHACLPropertyShape(owl_shacl_restriction=owl_shacl_restriction)
    
    for rdf_shacl_resource in RDFSHACLResource.rdf_shacl_identity_registry.values():
        if isinstance(rdf_shacl_resource, RDFSSHACLClass):
            SHACLNodeShape(owl_shacl_class=rdf_shacl_resource)


def __prepare_shacl_graph(ontology_graph: Graph) -> Graph():
    shacl_graph = Graph()
    for namespace_binding in ontology_graph.namespaces():
        shacl_graph.bind(namespace_binding[0], namespace_binding[1])
    return shacl_graph


def __serialise_shacl_shape_objects(ontology_graph: Graph, output_shacl_path: str):
    shacl_graph = __prepare_shacl_graph(ontology_graph=ontology_graph)
    SHACLShape.shacl_graph = shacl_graph
    
    for shacl_shape in SHACLShape.identity_registry.values():
        if isinstance(shacl_shape, SHACLPropertyShape):
            shacl_shape.serialise()
    
    for shacl_shape in SHACLShape.identity_registry.values():
        if isinstance(shacl_shape, SHACLNodeShape):
            shacl_shape.serialise()
    
    # if str(RDFSHACLResource.base_namespace).endswith('-Merged'):
    #     shacl_ontology = URIRef(str(RDFSHACLResource.base_namespace).replace('-Merged', '_SHACL'))
    # else:
    #     shacl_ontology = URIRef(str(RDFSHACLResource.base_namespace)[:-1] + '_SHACL/')
    # shacl_graph.add((shacl_ontology, RDF.type, OWL.Ontology))
    
    shacl_graph.serialize(output_shacl_path)


def __transform_owl_to_shacl(output_shacl_path: str, ontology_graph: Graph):
    __populate_shacl_shape_objects()
    __serialise_shacl_shape_objects(ontology_graph=ontology_graph, output_shacl_path=output_shacl_path)


def __get_base_namespace_from_ontology(ontology_graph: Graph) -> str:
    ontologies = list(ontology_graph.subjects(predicate=RDF.type, object=OWL.Ontology))
    if len(ontologies) == 0:
        return 'https://example.com'
    return str(ontologies[0])


def shacl(input_owl_path: str, output_shacl_path: str):
    logging.basicConfig(format='%(levelname)s %(asctime)s %(message)s', level=logging.INFO,
                        datefmt='%m/%d/%Y %I:%M:%S %p')
    ontology_graph = Graph()
    ontology_graph.parse(input_owl_path)
    base_namespace = __get_base_namespace_from_ontology(ontology_graph=ontology_graph)
    ontology_graph.bind(prefix='sh', namespace=Namespace(str(SH)))
    
    RDFSHACLResource.base_namespace = base_namespace
    RDFSHACLResource.ontology_graph = ontology_graph
    
    __collect_owl_constructs(ontology_graph=ontology_graph)
    __transform_owl_to_shacl(ontology_graph=ontology_graph, output_shacl_path=output_shacl_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Collects all ontologies imported from input ontology')
    parser.add_argument('--input_owl', help='Path to input ontology', metavar='IN_ONT')
    parser.add_argument('--output_shacl', help='Path to ontology mapping file', metavar='OUT_SHACL')
    args = parser.parse_args()
    
    shacl(input_owl_path=args.input_owl, output_shacl_path=args.output_shacl)
    
    # shacl(input_owl_path='../resources/idmp/ISO/ISO11238-Substances-Merged.ttl',
    #       output_shacl_path='/Users/pawel.garbacz/Documents/edmc/github/edmc/tools/shacl/ISO11238-Substances_SHACL.ttl')
