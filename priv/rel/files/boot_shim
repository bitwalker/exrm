#!/bin/sh

SCRIPT_DIR="$(cd $(dirname "$0") && pwd -P)"
RELEASE_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASES_DIR="$RELEASE_ROOT_DIR/releases"
REL_NAME="{{{PROJECT_NAME}}}"
REL_VSN=$(cat "$RELEASES_DIR"/start_erl.data | cut -d' ' -f2)
ERTS_VSN=$(cat "$RELEASES_DIR"/start_erl.data | cut -d' ' -f1)

exec "$RELEASES_DIR/$REL_VSN/$REL_NAME.sh" "$@"
