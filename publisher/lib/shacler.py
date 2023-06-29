import argparse
import logging

from rdflib import Graph, RDF, OWL, RDFS, SH, Namespace, XSD
from rdflib.term import Node, BNode, URIRef, Literal


class RDFSHACLResource:
    rdf_shacl_identity_registry = dict()
    base_namespace = None
    ontology_graph = Graph()
    
    def __repr__(self):
        pass
    
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
    
    def __repr__(self):
        return self.iri


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
    
    def __repr__(self):
        return self.iri


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
    
    def __repr__(self):
        return self.iri


class OWLSHACLRestriction(RDFSHACLResource):
    restriction_registry = dict()
    equivalent_registry = dict()
    
    def __init__(
            self,
            restriction_type: str,
            restricting_property: OWLSHACLProperty,
            restricting_class: RDFSSHACLClass,
            restricting_cardinality: int,
            restricted_classes: set):
        super().__init__(owl_construct_type=OWL.Restriction, iri=None)
        self.restriction_type = restriction_type
        self.restricting_property = restricting_property
        self.restricting_class = restricting_class
        self.restricting_cardinality = restricting_cardinality
        self.restricted_classes = restricted_classes
        OWLSHACLRestriction.restriction_registry[
            restriction_type, restricting_property, restricting_class, restricting_cardinality] = self
    
    def __get_hashable_attributes(self) -> list:
        return [self.restriction_type, self.restricting_property, self.restricting_class, self.restricting_cardinality]
    
    def __eq__(self, other):
        return self.__hash__() == other.__hash__()
    
    def __hash__(self):
        return str(self.__get_hashable_attributes()).__hash__()
    
    def get_inverse_restriction_if_exists(self):
        if self.restriction_type == OWL.someValuesFrom:
            inverse_properties_for_restricting_properties = set(
                self.ontology_graph.objects(subject=self.restricting_property.iri, predicate=OWL.inverseOf))
            for owl_shacl_restriction in self.restriction_registry.values():
                if owl_shacl_restriction.restriction_type == OWL.someValuesFrom:
                    counterpart_restricting_property_iri = owl_shacl_restriction.restricting_property.iri
                    if counterpart_restricting_property_iri in inverse_properties_for_restricting_properties:
                        return owl_shacl_restriction
        return None
    
    def __repr__(self):
        return str(self.__get_hashable_attributes()).__hash__()


class SHACLShape:
    identity_registry = dict()
    shacl_graph = Graph()
    
    def __init__(self, rdf_shacl_resource: RDFSHACLResource):
        self.rdf_shacl_resource = rdf_shacl_resource
        SHACLShape.identity_registry[rdf_shacl_resource] = self
    
    def serialise(self, use_equivalent_constraints: bool) -> str:
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
    serialisation_alterntive_register = dict()
    
    def __init__(self, owl_shacl_restriction: OWLSHACLRestriction):
        super().__init__(rdf_shacl_resource=owl_shacl_restriction)
        self.owl_shacl_restriction = owl_shacl_restriction
    
    def serialise(self, use_equivalent_constraints: bool):
        shacl_shape_id = \
            RDFSHACLResource.base_namespace + \
            self.get_iri_local_fragment(iri=self.rdf_shacl_resource.restriction_type) + \
            self.get_iri_local_fragment(iri=self.rdf_shacl_resource.restricting_property.iri) + \
            self.get_iri_local_fragment(self.rdf_shacl_resource.restricting_class.iri) + \
            SH.PropertyShape.fragment
        shacl_shape = URIRef(shacl_shape_id)
        
        self.shacl_graph.add((shacl_shape, RDF.type, SH.PropertyShape))
        if self.rdf_shacl_resource.restriction_type == OWL.someValuesFrom:
            self.__serialise_someValuesFrom(shacl_shape=shacl_shape, owl_shacl_restricton=self.owl_shacl_restriction)
            SHACLPropertyShape.serialisation_register[self] = shacl_shape
            if use_equivalent_constraints:
                if self.owl_shacl_restriction in OWLSHACLRestriction.equivalent_registry:
                    owl_shacl_inverse_restricton = OWLSHACLRestriction.equivalent_registry[self.owl_shacl_restriction]
                    inverse_of_prefix = OWL.inverseOf.fragment
                    inverse_shacl_shape_id = \
                        RDFSHACLResource.base_namespace + \
                        self.get_iri_local_fragment(iri=owl_shacl_inverse_restricton.restriction_type) + \
                        inverse_of_prefix + self.get_iri_local_fragment(iri=owl_shacl_inverse_restricton.restricting_property.iri) + \
                        self.get_iri_local_fragment(iri=owl_shacl_inverse_restricton.restricting_class.iri) + \
                        SH.PropertyShape.fragment
                    inverse_shacl_shape = URIRef(inverse_shacl_shape_id)
                    self.shacl_graph.add((inverse_shacl_shape, RDF.type, SH.PropertyShape))
                    self.__serialise_someValuesFrom_inverse(
                        shacl_shape=inverse_shacl_shape,
                        restricting_property_iri=owl_shacl_inverse_restricton.restricting_property.iri,
                        restricting_class=self.rdf_shacl_resource.restricting_class,
                        cardinality=owl_shacl_inverse_restricton.restricting_cardinality)
                    SHACLPropertyShape.serialisation_alterntive_register[self] = inverse_shacl_shape
    
    def __serialise_someValuesFrom(self, shacl_shape: URIRef, owl_shacl_restricton: OWLSHACLRestriction):
        self.shacl_graph.add((shacl_shape, SH.path, owl_shacl_restricton.restricting_property.iri))
        if isinstance(owl_shacl_restricton.restricting_class, OWLSHACLClass):
            self.shacl_graph.add((shacl_shape, URIRef('http://www.w3.org/ns/shacl#class'), owl_shacl_restricton.restricting_class.iri))
        if isinstance(owl_shacl_restricton.restricting_class, OWLSHACLDatatype):
            self.shacl_graph.add((shacl_shape, SH.datatype, owl_shacl_restricton.restricting_class.iri))
        if isinstance(owl_shacl_restricton.restricting_class, OWLSHACLLiteral):
            self.shacl_graph.add((shacl_shape, SH.nodeKind, SH.Literal))
        self.shacl_graph.add((shacl_shape, SH.minCount, Literal(owl_shacl_restricton.restricting_cardinality)))
        
    def __serialise_someValuesFrom_inverse(self, shacl_shape: URIRef, restricting_property_iri: URIRef, restricting_class: RDFSSHACLClass, cardinality: int):
        inverse_path_node = BNode()
        self.shacl_graph.add((inverse_path_node, SH.inversePath, restricting_property_iri))
        self.shacl_graph.add((shacl_shape, SH.path, inverse_path_node))
        if isinstance(restricting_class, OWLSHACLClass):
            self.shacl_graph.add((shacl_shape, URIRef('http://www.w3.org/ns/shacl#class'), restricting_class.iri))
        if isinstance(restricting_class, OWLSHACLDatatype):
            self.shacl_graph.add((shacl_shape, SH.datatype, restricting_class.iri))
        if isinstance(restricting_class, OWLSHACLLiteral):
            self.shacl_graph.add((shacl_shape, SH.nodeKind, SH.Literal))
        self.shacl_graph.add((shacl_shape, SH.minCount, Literal(cardinality)))


class SHACLNodeShape(SHACLShape):
    def __init__(self, owl_shacl_class: RDFSSHACLClass):
        super().__init__(rdf_shacl_resource=owl_shacl_class)
    
    def serialise(self, use_equivalent_constraints: bool):
        shacl_graph = self.shacl_graph
        
        relevant_shacl_property_shapes = self.__get_relevant_property_shapes()
        if len(relevant_shacl_property_shapes) == 0:
            return
        
        shacl_shape_id = self.rdf_shacl_resource.iri + SH.NodeShape.fragment
        shacl_shape = URIRef(shacl_shape_id)
        
        self.shacl_graph.add((shacl_shape, RDF.type, SH.NodeShape))
        self.shacl_graph.add((shacl_shape, SH.targetClass, self.rdf_shacl_resource.iri))
        
        for relevant_restriction in relevant_shacl_property_shapes:
            if use_equivalent_constraints:
                if relevant_restriction in SHACLPropertyShape.serialisation_alterntive_register:
                    straight_property_shape = SHACLPropertyShape.serialisation_register[relevant_restriction]
                    inverse_straight_property_shape = SHACLPropertyShape.serialisation_alterntive_register[
                        relevant_restriction]
                    alternative_paths_bnode = BNode()
                    alternative_paths_sublist = BNode()
                    shacl_graph.add((alternative_paths_bnode, RDF.first, straight_property_shape))
                    shacl_graph.add((alternative_paths_bnode, RDF.rest, alternative_paths_sublist))
                    shacl_graph.add((alternative_paths_sublist, RDF.first, inverse_straight_property_shape))
                    shacl_graph.add((alternative_paths_sublist, RDF.rest, RDF.nil))
                    shacl_graph.add((shacl_shape, URIRef(str(SH) + 'or'), alternative_paths_bnode))
            else:
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
                restricting_class_2_parents = \
                    set(RDFSHACLResource.ontology_graph.transitive_objects(
                        subject=restricting_class_2,
                        predicate=RDFS.subClassOf))
                if owl_shacl_class_1.restriction_type == OWL.someValuesFrom and owl_shacl_class_2.restriction_type == OWL.someValuesFrom:
                    if restricting_property_1 in restricting_property_2_parents and restricting_class_1 in restricting_class_2_parents:
                        if owl_shacl_class_2 in filtered_out_restrictions:
                            filtered_out_restrictions.remove(owl_shacl_class_2)
        
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
        restricted_classes = set()
        restricted_nodes = set(ontology_graph.transitive_subjects(object=owl_restriction, predicate=RDFS.subClassOf))
        for restricted_node in restricted_nodes:
            if not restricted_node == owl_restriction:
                restricted_class = __process_node(node=restricted_node, ontology_graph=ontology_graph)
                restricted_classes.add(restricted_class)
        if restricting_owl_shacl_class and restricting_owl_shacl_property:
            if restricting_owl_shacl_class.iri is not None:
                owl_shacl_restriction = \
                    OWLSHACLRestriction(
                        restriction_type=OWL.someValuesFrom,
                        restricting_property=restricting_owl_shacl_property,
                        restricting_class=restricting_owl_shacl_class,
                        restricting_cardinality=1,
                        restricted_classes=restricted_classes)
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


def __collect_owl_constructs(ontology_graph: Graph, use_equivalent_constraints: bool):
    owl_classes = ontology_graph.subjects(predicate=RDF.type, object=OWL.Class)
    for owl_class in owl_classes:
        if isinstance(owl_class, URIRef):
            __process_iri(iri=owl_class, ontology_graph=ontology_graph)
    if use_equivalent_constraints:
        __generate_inverse_restrictions(ontology_graph=ontology_graph)


def __generate_inverse_restrictions(ontology_graph: Graph):
    for owl_shacl_restriction_1 in OWLSHACLRestriction.restriction_registry.values():
        restricting_property_1 = owl_shacl_restriction_1.restricting_property.iri
        inverse_restricting_properties_1 = set(ontology_graph.objects(subject=restricting_property_1, predicate=OWL.inverseOf))
        extended_restricted_classes_1 = set()
        for restricted_class_1 in owl_shacl_restriction_1.restricted_classes:
            extended_restricted_classes_1 = extended_restricted_classes_1.union(set(ontology_graph.transitive_subjects(predicate=RDFS.subClassOf, object=restricted_class_1)))
        if owl_shacl_restriction_1.restriction_type == OWL.someValuesFrom:
            for owl_shacl_restriction_2 in OWLSHACLRestriction.restriction_registry.values():
                restricting_property_2 = owl_shacl_restriction_2.restricting_property.iri
                extended_restricted_classes_2 = set()
                for restricted_class_2 in owl_shacl_restriction_2.restricted_classes:
                    extended_restricted_classes_2 = extended_restricted_classes_2.union(set(ontology_graph.transitive_subjects(predicate=RDFS.subClassOf, object=restricted_class_2)))
                if owl_shacl_restriction_2.restriction_type == OWL.someValuesFrom:
                    inverse_restricting_properties_2 = set(ontology_graph.objects(subject=restricting_property_2, predicate=OWL.inverseOf))
                    if restricting_property_1 in inverse_restricting_properties_2 or restricting_property_2 in inverse_restricting_properties_1:
                        if owl_shacl_restriction_1.restricting_class in extended_restricted_classes_2 and owl_shacl_restriction_2.restricting_class in extended_restricted_classes_1:
                            OWLSHACLRestriction.equivalent_registry[owl_shacl_restriction_1] = owl_shacl_restriction_2
                        if owl_shacl_restriction_2.restricting_class in owl_shacl_restriction_1.restricted_classes and owl_shacl_restriction_1.restricting_class in owl_shacl_restriction_2.restricted_classes:
                            OWLSHACLRestriction.equivalent_registry[owl_shacl_restriction_2] = owl_shacl_restriction_1


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


def __serialise_shacl_shape_objects(ontology_graph: Graph, output_shacl_path: str, use_equivalent_constraints: bool):
    shacl_graph = __prepare_shacl_graph(ontology_graph=ontology_graph)
    SHACLShape.shacl_graph = shacl_graph
    
    for shacl_shape in SHACLShape.identity_registry.values():
        if isinstance(shacl_shape, SHACLPropertyShape):
            shacl_shape.serialise(use_equivalent_constraints=use_equivalent_constraints)
    
    for shacl_shape in SHACLShape.identity_registry.values():
        if isinstance(shacl_shape, SHACLNodeShape):
            shacl_shape.serialise(use_equivalent_constraints=use_equivalent_constraints)
    
    shacl_graph.serialize(output_shacl_path)


def __transform_owl_to_shacl(output_shacl_path: str, ontology_graph: Graph, use_equivalent_constraints: bool):
    __populate_shacl_shape_objects()
    __serialise_shacl_shape_objects(ontology_graph=ontology_graph, output_shacl_path=output_shacl_path, use_equivalent_constraints=use_equivalent_constraints)


def __get_base_namespace_from_ontology(ontology_graph: Graph) -> str:
    ontologies = list(ontology_graph.subjects(predicate=RDF.type, object=OWL.Ontology))
    if len(ontologies) == 0:
        return 'https://example.com'
    return str(ontologies[0])


def shacl(input_owl_path: str, output_shacl_path: str, use_equivalent_constraints=True):
    logging.basicConfig(format='%(levelname)s %(asctime)s %(message)s', level=logging.INFO,
                        datefmt='%m/%d/%Y %I:%M:%S %p')
    ontology_graph = Graph()
    ontology_graph.parse(input_owl_path)
    base_namespace = __get_base_namespace_from_ontology(ontology_graph=ontology_graph)
    ontology_graph.bind(prefix='sh', namespace=Namespace(str(SH)))
    
    RDFSHACLResource.base_namespace = base_namespace
    RDFSHACLResource.ontology_graph = ontology_graph
    
    __collect_owl_constructs(ontology_graph=ontology_graph, use_equivalent_constraints=use_equivalent_constraints)
    __transform_owl_to_shacl(ontology_graph=ontology_graph, output_shacl_path=output_shacl_path, use_equivalent_constraints=use_equivalent_constraints)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Collects all ontologies imported from input ontology')
    parser.add_argument('--input_owl', help='Path to input ontology', metavar='IN_ONT')
    parser.add_argument('--output_shacl', help='Path to ontology mapping file', metavar='OUT_SHACL')
    args = parser.parse_args()

    shacl(input_owl_path=args.input_owl, output_shacl_path=args.output_shacl)
    
    # shacl(
    #     input_owl_path='../resources/idmp_current/dev.idmp-quickstart.ttl',
    #     output_shacl_path='../resources/idmp_current/dev.idmp-quickstart.shacl',
    #     use_equivalent_constraints=True)
