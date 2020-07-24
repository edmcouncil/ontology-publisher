#!/bin/bash

export HOME="/home/sam/workspace"
export ONTPUB_FAMILY="DynamicSpectrumAccess"
export ONTPUB_EXEC="./publish.sh hygiene"
export ONTPUB_SUBDIR="/ontologies"
export ONTPUB_EXCLUDED="/archived"

# ./docker-run.sh --dev --build --shell
./docker-run.sh --dev --build --run
