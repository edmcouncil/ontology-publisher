# Ontology Builder

## What is the Ontology Builder?

The Ontology Builder is a Docker Image that executes the build process, testing and publishing
the git-based content of an Ontology "Family" like FIBO.

The Ontology Builder can process any Ontology Family as long as it is based into one git repository.
 
It has as input a git-clone of the repository of the Ontology Family (the source) and as output a target
directory with tested and publishable content.
This content can be copied to a site, in the FIBO case that would be
[https://spec.edmcouncil.org/fibo](https://spec.edmcouncil.org/fibo).

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

If you'd like to publish the image to Docker Hub:

```bash
./docker-run.sh --pushimage
```

## Jenkins

TODO: The text below this point needs to be updated.

## How can I get access?

The FIBO Jenkins server runs at https://jenkins.edmcouncil.org.
It uses Github user authentication, so everyone needs to have a Github userid in order to access the Jenkins server.
This userid needs to be part of the EDM Council organization on Github.

## Jenkins Master & Slaves

The server that runs at https://jenkins.edmcouncil.org is the so called "Jenkins Master Server". 
The idea is that most common jobs will run there, until we need more capacity. In that case we can delegate the work
of running Jenkins jobs to "slaves". These are Jenkins-servers that do not have their own GUI, they're installed on 
any other machine automatically by the Jenkins Master, and simply run Jenkins jobs.

### Vendor Slaves

The facility that Jenkins provides to run jobs on a slave, can also be used to run specific jobs on special hardware. 
That hardware could be hosted elsewhere, for instance at the premises of a vendor in the FIBO space, such as a triple
store vendor. These vendors could then run the FIBO test jobs on their own hardware, all configured and tuned as good
as it gets. Whenever a change is pulled into the FIBO repository, all sorts of jobs can get triggered on many different
machines, validating that change.

### fibo-infra repo & directory structure

- [`bin/`](../bin/README.md)
  
  The `bin/` directory contains scripts and executable tools (like jena) that
  can be used on your own computer or in a Jenkins job context.
  
  
