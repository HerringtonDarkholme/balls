#!/bin/bash
[[ -z "$BALLS_LIB" ]] && BALLS_LIB=.

[[ -z "$BALLS_CONF" ]] && BALLS_CONF=./config/config.sh
[[ -z "$BALLS_ROOT" ]] && BALLS_ROOT=$(readlink -f "$(dirname $BALLS_CONF)/../")
[[ -z "$BALLS_LIB" ]] && BALLS_LIB=$(dirname $0)

[[ -z "$BALLS_TMP" ]] && BALLS_TMP=/tmp/balls
[[ -d "$BALLS_TMP" ]] || mkdir -p "$BALLS_TMP"

[[ -z "$BALLS_PORT" ]] && BALLS_PORT=3000

[[ -z "$BALLS_VIEWS" ]] && BALLS_VIEWS=$BALLS_ROOT/app/views
[[ -z "$BALLS_ACTIONS" ]] && BALLS_ACTIONS=$BALLS_ROOT/app/controllers

. $BALLS_LIB/util.sh
. $BALLS_LIB/http.sh
. $BALLS_LIB/router.sh
. $BALLS_LIB/server.sh
. $BALLS_LIB/view.sh
. $BALLS_LIB/model.sh
. $BALLS_LIB/params.sh
