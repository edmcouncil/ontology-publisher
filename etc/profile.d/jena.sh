#!/usr/bin/env bash

echo JENA_HOME=${JENA_HOME}

if [ -z "${JENA_HOME}" ] ; then
  echo "ERROR: JENA_HOME is empty"
else
  export PATH=${PATH}:${JENA_HOME}/bin
fi
