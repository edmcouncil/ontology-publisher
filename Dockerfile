#
# This Dockerfile defines a docker image for a docker container that you can run
# locally on your PC (provided that you have Docker for Windows or Docker for Mac
# running). It can also be deployed as a container in the ECS service of Amazon AWS.
#
# The functionality of the container is to run the whole publishing process or a part therof.
#
# You can build this image yourself by executing the following command in the same
# directory as where you found this Dockerfile:
#
# docker build .
#
# Using Alpine linux because it's ultra-lightweight, designed for running in a Docker
# container.
#
# - alpine is the name of the Linux brand we're using, which is the smallest linux keeping the image as small
#   as possible.
#
FROM alpine:3.17

#
# Some meta data, can only have one maintainer unfortunately
#
LABEL maintainer="jacobus.geluk@agnos.ai"
LABEL authors="jacobus.geluk@agnos.ai,dallemang@workingontologist.com,kartgk@gmail.com,pete.rivett@adaptive.com"
LABEL owner="Enterprise Data Management Council"

#
# These ARG-variables are NOT necessarily environment variables that end up in the docker container itself. Unless
# their value is copied into a same named ENV variable. They're just there during the image build process itself.
# You can override their default values with any number of "--build-arg" options on the "docker build" command line.
#
ARG ONTPUB_FAMILY=fibo
ARG HYGIENE_TEST_PARAMETER_VALUE=edmcouncil
ARG ONTPUB_IS_DARK_MODE=1

ENV \
  BASH_ENV=/etc/profile \
  INPUT=/input \
  OUTPUT=/output \
  TMPDIR=/var/tmp

RUN install -dv -m0755 /publisher && install -dv -g 65534 -m0775 "${TMPDIR}" && \
  ln -s /etc/bashrc /etc/profile.d/spec.sh

#
# Installing bash, curl, git, grep, coreutils
#
RUN \
  echo ================================= install basics >&2 && \
  apk --no-cache add \
    curl wget \
    bash git grep sed findutils coreutils tree jq yq bc xmlstarlet util-linux \
    zip tar xz \
    openjdk11 \
    python3-dev py3-pip py3-wheel py3-cachetools py3-frozendict py3-isodate py3-lxml cython py3-pandas \
    libxml2-dev libxslt-dev \
    perl fontconfig make \
    gcc g++ linux-headers libc-dev && \
    # "bash" preferable to "busybox"
    ln -sf bash /bin/sh && \
    ln -sf python3 /usr/bin/python && \
  #
  # Clean up
  #
  rm -rf /var/lib/apt/lists/*

#
# Installing Apache Jena
# INFRA-496 jena-arq-${JENA_VERSION}.jar: workaround to change default JSON-LD-10 output: JSONLD10 = JSONLD10_EXPAND_PRETTY instead of JSONLD10_COMPACT_PRETTY
#
ENV \
  JENA_VERSION="4.6.1" \
  JENA_HOME=/usr/share/java/jena/latest \
  PATH=${PATH}:/usr/lib/jvm/java-11-openjdk/bin:/usr/share/java/jena/latest/bin
RUN \
  echo ================================= install jena ${JENA_VERSION} >&2 && \
  name="apache-jena-${JENA_VERSION}" ; \
  targz="${name}.tar.gz" ; \
  url="http://archive.apache.org/dist/jena/binaries/${targz}" ; \
  echo "Downloading ${url}:" >&2 ; \
  curl --location --silent --show-error --output /var/tmp/${targz} --url "${url}" && \
  (mkdir -p /usr/share/java/jena || true) && \
  cd /usr/share/java/jena && \
  tar xzf /var/tmp/${targz} && \
  rm -f /var/tmp/${targz} && \
  mv ${name} ${JENA_VERSION} && \
  ln -s ${JENA_VERSION} latest && \
  ln -s /usr/share/java/jena/latest/bin/riot /usr/local/bin/riot && \
  ln -s /usr/share/java/jena/latest/bin/sparql /usr/local/bin/sparql && \
  ln -s /usr/share/java/jena/latest/bin/turtle /usr/local/bin/turtle && \
  cd ${JENA_VERSION} && \
  unzip lib-src/jena-arq-${JENA_VERSION}-sources.jar org/apache/jena/riot/RDFFormat.java && \
  rm -rf src-examples lib-src bat && \
  perl -pi -e 's/(\WJSONLD10\s+=\s+JSONLD(?:10)?_)(?:COMPACT_)?(PRETTY)/\1EXPAND_\2/g' org/apache/jena/riot/RDFFormat.java && \
  javac -cp /usr/share/java/jena/${JENA_VERSION}/lib/jena-arq-${JENA_VERSION}.jar org/apache/jena/riot/RDFFormat.java && \
  zip -u /usr/share/java/jena/${JENA_VERSION}/lib/jena-arq-${JENA_VERSION}.jar org/apache/jena/riot/RDFFormat.class && \
  rm -rf org && \
  cd / && \
  version="$(echo $(tdb2.tdbloader --version | grep Jena | grep VERSION | cut -d: -f3))" && \
  echo "installed version="[${version}]"" && \
  test "${version}" == "${JENA_VERSION}"

#
# Installing XlsxWriter, rdflib, PyLD
#
RUN \
  echo ================================= install XlsxWriter, rdflib, PyLD >&2 && \
  pip3 install XlsxWriter rdflib PyLD

#
# Installing [ROBOT](https://github.com/ontodev/robot)
#
ENV ROBOT_VERSION="v1.9.1"
RUN \
  wget -m -nH -nd -P /usr/local/bin https://raw.githubusercontent.com/ontodev/robot/${ROBOT_VERSION:-master}/bin/robot && \
  wget -m -nH -nd -P /usr/local/bin https://github.com/ontodev/robot/releases/${ROBOT_VERSION:+download/}${ROBOT_VERSION:=latest/download}/robot.jar && \
  chmod +x /usr/local/bin/robot

COPY etc /etc
COPY root /root

#
# Installing [shacler](https://github.com/edmcouncil/tools/)
#
RUN \
  wget -m -nH -nd -P /publisher/lib https://raw.githubusercontent.com/edmcouncil/tools/develop/shacl/shacler.py

#
# Installing the rdf-toolkit
#
#ENV RDFTOOLKIT_JAR=/publisher/lib/rdf-toolkit.jar
ENV RDFTOOLKIT_JAR=/usr/share/java/rdf-toolkit/rdf-toolkit.jar
RUN \
  echo ================================= install the RDF toolkit >&2 && \
  toolkit_build="lastSuccessfulBuild" ; \
  url="https://jenkins.edmcouncil.org/view/rdf-toolkit/job/rdf-toolkit-build/" ; \
  url="${url}${toolkit_build}/artifact/target/rdf-toolkit.jar" ; \
  echo "Downloading ${url}:" >&2 ; \
  mkdir -p /usr/share/java/rdf-toolkit ; \
  curl --location --silent --show-error --output ${RDFTOOLKIT_JAR} --url "${url}"

#
# Install OntoViewer Toolkit
#
ENV ONTOVIEWER_TOOLKIT_JAR=/usr/share/java/onto-viewer/onto-viewer-toolkit.jar
RUN \
  echo "================================= install OntoViewer Toolkit" >&2 && \
  url='https://jenkins.edmcouncil.org/view/onto-viewer/job/onto-viewer-publish/lastSuccessfulBuild/artifact/onto-viewer-toolkit/target/onto-viewer-toolkit.jar' ; \
  mkdir -p /usr/share/java/onto-viewer ; \
  echo "Downloading ${url}:" >&2 ; \
  curl --location --silent --show-error --output "${ONTOVIEWER_TOOLKIT_JAR}" --url "${url}"

#
# <skip in dev mode begin>
#
COPY /publisher /publisher

#
# Do some after-COPY "optimizations" to get rid of Windows CRLF's
#
RUN find /publisher/ -name '*.sh' | xargs sed -i 's/\r//'
#
# <skip in dev mode end>
#

#
# Your ontology repos are supposed to be under /input
#
#VOLUME ["${INPUT}" ]
#
# Mount your "target directory", the place where all published files end up, here
#
#VOLUME ["${OUTPUT}"]
#
# Mount a directory for temporary files
#
VOLUME ["${TMPDIR}"]

WORKDIR /publisher

RUN \
  echo PATH=${PATH} && \
  echo "export PATH=${PATH}" >> /etc/bashrc && \
  sed -i "s/<ONTPUB_FAMILY>/${ONTPUB_FAMILY}/g ; s/<HYGIENE_TEST_PARAMETER_VALUE>/${HYGIENE_TEST_PARAMETER_VALUE}/g ; s/<ONTPUB_IS_DARK_MODE>/${ONTPUB_IS_DARK_MODE}/g" /etc/bashrc && \
  ln -sf /var/tmp/.gitconfig /root/.gitconfig && \
  ln -sf /var/tmp/.gitconfig /.gitconfig && \
  rm -rvf /root/{.wget-hsts,.cache}

CMD ["./publish.sh"]

