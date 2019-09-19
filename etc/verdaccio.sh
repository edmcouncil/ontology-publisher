#!/bin/bash
exec /usr/bin/verdaccio -c "$(dirname "${0}")/verdaccio.yaml" &>/dev/null &
