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
FROM maven:3-jdk-12-alpine

#
# Some meta data, can only have one maintainer
#
LABEL maintainer="jacobus.geluk@agnos.ai"
LABEL authors="jacobus.geluk@agnos.ai,dallemang@workingontologist.com,kartgk@gmail.com,pete.rivett@adaptive.com"
LABEL owner="Enterprise Data Management Council"

#
# These ARG-variables are NOT environment variables that end up in the docker container itself.
# They're just there during the image build process itself. You can override their default values
# with any number of "--build-arg" options on the "docker build" command line.
#
ARG FAMILY

#
# TODO: Move the FAMILY env to ARGS so that this can be used for other ontologies than FIBO
#
ENV \
  FAMILY=${FAMILY:-fibo} \
  INPUT=/input \
  OUTPUT=/output \
  RUNNING_IN_DOCKER=1 \
  TMPDIR=/var/tmp

RUN mkdir -p /publisher ${TMPDIR} || true

#
# Installing bash, curl, git, grep, coreutils
#
RUN \
  apk update && \
  apk upgrade && \
  apk add \
    bash curl git grep sed findutils coreutils tree jq \
    zip tar \
    python python3 py3-setuptools \
    gcc linux-headers libc-dev \
  && \
  #
  # Clean up
  #
  rm -rf /var/lib/apt/lists/* && \
  rm /var/cache/apk/*

#
# Installing pandoc
#
ENV \
  pandoc_available=1 \
  pandoc_bin=/usr/local/bin/pandoc
RUN \
  pandoc_version="2.2.2.1" ; \
  echo ================================= install pandoc ${pandoc_version} >&2 && \
  targz="pandoc-${pandoc_version}-linux.tar.gz" ; \
  url="https://github.com/jgm/pandoc/releases/download/${pandoc_version}/${targz}" ; \
  echo "Downloading ${url}:" >&2 ; \
  curl --location --silent --show-error --output /tmp/${targz} --url "${url}" && \
  mkdir -p /usr/share/pandoc && \
  cd /usr/share/pandoc && \
  tar xzf /tmp/${targz} --strip-components 1 -C . && \
  cd bin && \
  mv * .. && \
  cd .. && \
  rm -rf bin share && \
  ln -s /usr/share/pandoc/pandoc /usr/local/bin/pandoc && \
  ./pandoc --version

#
# Install serd
#
ENV \
  SERD=/usr/local/bin/serdi \
  SERDI=/usr/local/bin/serdi
RUN \
  serd_version="0.28.0" ; \
  echo ================================= install serd ${serd_version} >&2 && \
  name="serd-${serd_version}" ; \
  tarbz2="${name}.tar.bz2" ; \
  url="http://download.drobilla.net/${tarbz2}" ; \
  ( \
    mkdir -p /tmp/build-serd ; \
    cd /tmp/build-serd ; \
    curl --location --silent --show-error --output "${tarbz2}" --url "${url}" ; \
    cat "${tarbz2}" | tar -xj ; \
    cd "${name}" ; \
    ./waf configure ; \
    ./waf ; \
    ./waf install ; \
  ) && \
  rm -rf /tmp/build-serd && \
  test "$(which serdi)" == "${SERD}"

#
# Installing the rdf-toolkit
#
ENV RDFTOOLKIT_JAR=/usr/share/java/rdf-toolkit/rdf-toolkit.jar
RUN \
  echo ================================= install the RDF toolkit >&2 && \
  url="https://jenkins.edmcouncil.org/view/rdf-toolkit/job/rdf-toolkit-build/" ; \
  url="${url}lastSuccessfulBuild/artifact/target/scala-2.12/rdf-toolkit.jar" ; \
  echo "Downloading ${url}:" >&2 ; \
  mkdir -p /usr/share/java/rdf-toolkit ; \
  curl --location --silent --show-error --output ${RDFTOOLKIT_JAR} --url "${url}"

#
# Installing Apache Jena
#
ENV \
  JENA_VERSION="3.9.0" \
  JENA_HOME=/usr/share/java/jena/latest
RUN \
  echo ================================= install jena ${JENA_VERSION} >&2 && \
  name="apache-jena-${JENA_VERSION}" ; \
  targz="${name}.tar.gz" ; \
  url="http://www-us.apache.org/dist/jena/binaries/${targz}" ; \
  echo "Downloading ${url}:" >&2 ; \
  curl --location --silent --show-error --output /tmp/${targz} --url "${url}" && \
  (mkdir -p /usr/share/java/jena || true) && \
  cd /usr/share/java/jena && \
  tar xzf /tmp/${targz} && \
  rm -f /tmp/${targz} && \
  mv ${name} ${JENA_VERSION} && \
  ln -s ${JENA_VERSION} latest && \
  ln -s /usr/share/java/jena/latest/bin/riot /usr/local/bin/riot && \
  ln -s /usr/share/java/jena/latest/bin/sparql /usr/local/bin/sparql && \
  ln -s /usr/share/java/jena/latest/bin/turtle /usr/local/bin/turtle && \
  cd ${JENA_VERSION} && \
  rm -rf src-examples lib-src bat && \
  cd /

#
# Installing old version of Apache Jena because SPIN 2.0.0 needs it
#
ENV JENA_OLD_VERSION="3.0.1"
RUN \
  echo ================================= install jena ${JENA_OLD_VERSION} for SPIN >&2 && \
  name="apache-jena-${JENA_OLD_VERSION}" ; \
  targz="${name}.tar.gz" ; \
  url="http://archive.apache.org/dist/jena/binaries/${targz}" ; \
  echo "Downloading ${url}:" >&2 ; \
  curl --location --silent --show-error --output /tmp/${targz} --url "${url}" && \
  (mkdir -p /usr/share/java/jena || true) && \
  cd /usr/share/java/jena && \
  tar xzf /tmp/${targz} && \
  rm -f /tmp/${targz} && \
  mv ${name} ${JENA_OLD_VERSION} && \
  ln -s ${JENA_OLD_VERSION} jena-old && \
  cd ${JENA_OLD_VERSION} && \
  rm -rf src-examples lib-src bat javadoc-* && \
  cd /

#
# Installing SPIN
#
ENV SPIN_VERSION="2.0.0"
RUN \
  echo ================================= install SPIN ${SPIN_VERSION} >&2 && \
  name="spin-${SPIN_VERSION}" ; \
  zip="${name}-distribution.zip" ; \
  url="https://www.topquadrant.com/repository/spin/org/topbraid/spin/${SPIN_VERSION}/${zip}" ; \
  echo "Downloading ${url}:" >&2 ; \
  curl --location --silent --show-error --output /tmp/${zip} --url "${url}" && \
  (mkdir -p /usr/share/java/spin || true) && \
  cd /usr/share/java/spin && \
  unzip -q /tmp/${zip} && \
  rm -f /tmp/${zip} && \
  cd src-tools && \
  find . -name '*.java' | \
  xargs javac -cp "/usr/share/java/jena/jena-old/lib/*:/usr/share/java/spin/spin-${SPIN_VERSION}.jar" && \
  cd .. && \
  rm -rf src-examples src README.TXT RELEASE-NOTES.TXT && \
  cd /

#
# Installing XlsxWriter
#
RUN \
  echo ================================= install XlsxWriter >&2 && \
  easy_install-3.6 XlsxWriter

#
# Installing rdflib
#
RUN \
  echo ================================= install rdflib >&2 && \
  easy_install-3.6 rdflib

#
# Installing Widoco
#
RUN \
  widoco_version="1.4.7" ; \
  widoco_root_url="https://jenkins.edmcouncil.org/view/widoco/job/widoco-build/lastStableBuild/es.oeg\$widoco/artifact/es.oeg" ; \
  echo ================================= install widoco ${widoco_version} >&2 && \
  #
  # Creating widoco and its config directory and storing an empty config file in there which suppresses
  # an annoying log message at each invocation of widoco
  #
  mkdir -p /usr/share/java/widoco/config || true && \
  touch /usr/share/java/widoco/config/config.properties && \
  curl \
    --fail \
    --insecure \
    --location \
    --output /usr/share/java/widoco/widoco-launcher.jar \
    --url ${widoco_root_url}/widoco/${widoco_version}/widoco-${widoco_version}-launcher.jar && \
  test -f /usr/share/java/widoco/widoco-launcher.jar

#
# Installing log4j (needed by widoco)
#
RUN \
  log4j_version="2.11.1" ; \
  log4j_mirror="http://apache.javapipe.com/logging/log4j" ; \
  log4j_targz_url="${log4j_mirror}/${log4j_version}/apache-log4j-${log4j_version}-bin.tar.gz" ; \
  echo ================================= install log4j ${log4j_version} >&2 && \
  mkdir -p /usr/share/java/log4j || true && \
  curl \
    --fail \
    --insecure \
    --location \
    --output /usr/share/java/log4j/apache-log4j-bin.tar.gz \
    --url "${log4j_targz_url}" && \
  test -f /usr/share/java/log4j/apache-log4j-bin.tar.gz && \
  ( \
    cd /usr/share/java/log4j && \
    ls -1 && \
    tar \
      --strip-components=1 \
      --wildcards \
      --exclude='*-javadoc.jar' \
      --exclude='*-tests.jar' \
      --exclude='*-sources.jar' \
      -xvzf \
      apache-log4j-bin.tar.gz \
      '*/log4j-api*.jar' \
      '*/log4j-1.2-api*.jar' \
      '*/log4j-core-*.jar' && \
    rm apache-log4j-bin.tar.gz && \
    mv -v log4j-api-*.jar log4j-api.jar && \
    mv -v log4j-core-*.jar log4j-core.jar && \
    mv -v log4j-1.2-api-*.jar log4j-1.2-api.jar \
  )

COPY etc /etc
COPY root /root

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
# Mount your local git clone containing all the OWL files here
#
VOLUME ["${INPUT}/${FAMILY}"]
#
# Mount your "target directory", the place where all published files end up, here
#
VOLUME ["${OUTPUT}"]
#
# Mount a directory for temporary files
#
VOLUME ["${TMPDIR}"]

WORKDIR /publisher

CMD ["./publish.sh"]

