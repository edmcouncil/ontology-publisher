#!/bin/bash

PARENT_DIR=$(cd .. && pwd)
export HOME=${$HOME:-$PARENT_DIR}
export ONTPUB_FAMILY=${ONTPUB_FAMILY:-DynamicSpectrumAccess}
export ONTPUB_EXEC="./publish.sh hygiene"
export ONTPUB_SUBDIR="/ontologies"
export ONTPUB_EXCLUDED="/archived"
export HYGIENE_NAMESPACE_REGEX="twc"
export RUN_OPT=${RUN_OPT:-"--run"}

./docker-run.sh --dev --build ${RUN_OPT}
