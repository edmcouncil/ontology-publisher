<img src="https://github.com/edmcouncil/html-pages/raw/develop/general/assets/img/EDM-council-RGB_200w.png" width="200" align="right"/>


# Ontology Builder

## What is the Ontology Builder?

The Ontology Builder is a Docker Image that executes the build process, testing and publishing
the git-based content of an Ontology "Family".

The Ontology Builder can process any Ontology Family as long as it is based into one git repository.
 
It has as input a git-clone of the repository of the Ontology Family (the source) and as output a target
directory with tested and publishable content.

## Local Usage

The Ontology Builder can be run "locally" on your Ontology Development machine provided that you
have installed Docker.

- [Docker for Windows](https://www.docker.com/docker-windows)
- [Docker for Mac](https://www.docker.com/docker-mac)

Run the publisher with the following command:

```bash
./docker-run.sh --run
```

If you'd like to have a shell inside the Docker Container use this:

```bash
./docker-run.sh --shell
```

If you'd like the ontology-publisher's container to use your local drive for both input and output then add 
the `--dev` parameter:

```bash
./docker-run.sh --shell --dev
```

If you'd like the ontology-publisher's container to start with a clean slate in the output directory then add `--clean`: 

```bash
./docker-run.sh --shell --dev --clean
```

If you'd like to just build the image:

```bash
./docker-run.sh --buildimage
```

The `--rebuildimage` option forces the image to be rebuilt with the ability
to change the default values for certain environment variables (see [docker-run.sh --rebuild option](./docker-run.sh)), e.g .:

```bash
env ONTPUB_FAMILY="onto" ./docker-run.sh --rebuildimage
```
sets the default ontology family to `onto`.

If you'd like to publish the image to Docker Hub:

```bash
./docker-run.sh --pushimage
```

## Environment variables

When running ontology-publisher it is possible to set environment variables appropriate for the processed ontology as follows:

```bash
env <VARIABLE_NAME>=<VARIABLE_VALUE> [<VARIABLE_NAME1>=<VARIABLE_VALUE1>...] ./docker-run.sh [OPTION...]
```

for example:

```bash
env ONTPUB_FAMILY="onto" ./docker-run.sh --shell --dev
```

List of allowed `<VARIABLE_NAME>` (and defaults for `<VARIABLE_VALUE>`):

- `ONTPUB_FAMILY` :- ontology name (base for many other values), e.g. `onto` (default: `fibo`); this variable is also possible to set during build time (see `--rebuildimage` option)
- `URI_SPACE` :- a common "URI namespace" for all ontologies - see [4.2 Patterns for resource URIs](https://www.w3.org/TR/void/#pattern), e.g. `https://spec.edmcouncil.org/fibo/ontology/`; overrides ontology IRI=`https://${ONTPUB_SPEC_HOST}/${ONTPUB_FAMILY}/ontology/`
- `BRANCH_TAG` :- suffix appended to common "URI namespace" used to construct `versionIRI` and `rdf:resource` for `owl:imports`, e.g. `release/202101`
  overrides the default _branch/tag_, where `branch` and `tag` are values calculated from the parameters of the git repository containing the Ontology Family
  use `/` to set a blank value
- `DATADICTIONARY_COLUMNS` :- list of parameters (separated by a vertical bar `|`), which are the values of the `extract-data-column` options (see [OntoViewer Toolkit - Options](https://github.com/edmcouncil/onto-viewer/blob/develop/onto-viewer-toolkit/README.md#options)),
  used when generating [the "data dictionary" product](https://github.com/edmcouncil/ontology-publisher/tree/develop/publisher/product/datadictionary) (`extract-data` goal - see [OntoViewer Toolkit - Goals](https://github.com/edmcouncil/onto-viewer/blob/develop/onto-viewer-toolkit/README.md#goals))
  e.g. `synonym=http://example.com/synonym,https://www.omg.org/spec/Commons/AnnotationVocabulary/synonym|example=http://www.w3.org/2004/02/skos/core#example`
- `ONTPUB_SPEC_HOST` :- the basis of the ontology IRI=`https://${ONTPUB_SPEC_HOST}/${ONTPUB_FAMILY}/ontology/`, e.g. `onto.example.org` (default: `spec.edmcouncil.org`)
- `DEV_SPEC` :- the name of the file (inside the directory named `${ONTPUB FAMILY}` containing the "Development" ontology, e.g. `AboutFIBODev.rdf` (default: `About${ONTPUB_FAMILY}Dev.rdf`)
- `PROD_SPEC` :- the name of the file (inside the directory named `${ONTPUB FAMILY}`containing the "Production" ontology, e.g. `AboutFIBOProd.rdf` (default: `About${ONTPUB_FAMILY}Prod.rdf`)
- `HYGIENE_TEST_PARAMETER_VALUE` :- filter pattern, e.g. `example` (default: `edmcouncil`); this variable is also possible to set during build time (see `--rebuildimage` option)
- `HYGIENE_WARN_INCONSISTENCY_SPEC_FILE_NAME` :- the name of the file (inside the directory named `${ONTPUB FAMILY}`for which the "warning" level consistency check test will be performed (i.e. in the case of a lack of consistency, the ontology building process is not terminated), e.g. `AboutFIBODev.rdf` (no default - in the absence of a value, the tests will not be run)
- `HYGIENE_ERROR_INCONSISTENCY_SPEC_FILE_NAME` :- the name of the file (inside the directory named `${ONTPUB FAMILY}` for which the "error" level consistency check test will be performed (i.e. in the case of a lack of consistency, the ontology building process is terminated with an error message), e.g. `AboutFIBOProd.rdf` (no default - in the absence of a value, the tests will not be run)
- `ONTPUB_MERGED_INFIX` :- infix for "merged" files, e.g. `-Merged` (no default - in the absence of a value, the merged files will not be created)

## Jenkins

TODO: The text below this point needs to be updated.

## How can I get access?

The Jenkins server runs at https://jenkins.edmcouncil.org.
It uses Github user authentication, so everyone needs to have a Github userid in order to access the Jenkins server.
This userid needs to be part of the EDM Council organization on Github.

## Jenkins Master & Slaves

The server that runs at https://jenkins.edmcouncil.org is the so called "Jenkins Master Server". 
The idea is that most common jobs will run there, until we need more capacity. In that case we can delegate the work
of running Jenkins jobs to "slaves". These are Jenkins-servers that do not have their own GUI, they're installed on 
any other machine automatically by the Jenkins Master, and simply run Jenkins jobs.

### Vendor Slaves

The facility that Jenkins provides to run jobs on a slave, can also be used to run specific jobs on special hardware. 
That hardware could be hosted elsewhere, for instance at the premises of a vendor in the ontology space, such as a triple
store vendor. These vendors could then run the ontology test jobs on their own hardware, all configured and tuned as good
as it gets. Whenever a change is pulled into the ontology repository, all sorts of jobs can get triggered on many different
machines, validating that change.

### ontology-infra repo & directory structure

- [`bin/`](../bin/README.md)
  
  The `bin/` directory contains scripts and executable tools (like jena) that
  can be used on your own computer or in a Jenkins job context.
  
  
