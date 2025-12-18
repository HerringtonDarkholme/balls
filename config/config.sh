#!/bin/bash

# Base configuration for Bash on Balls
BALLS_ROOT=${BALLS_ROOT:-$(readlink -f "$(dirname "$0")/..")}
BALLS_ENV=${BALLS_ENV:-development}
BALLS_PORT=${BALLS_PORT:-3000}
BALLS_RELOAD=${BALLS_RELOAD:-1}
BALLS_VIEWS=${BALLS_VIEWS:-$BALLS_ROOT/app/views}
BALLS_ACTIONS=${BALLS_ACTIONS:-$BALLS_ROOT/app/controllers}
BALLS_MODELS=${BALLS_MODELS:-$BALLS_ROOT/app/models}
BALLS_DB_DIR=${BALLS_DB_DIR:-$BALLS_ROOT/db}
BALLS_DB_FILE=${BALLS_DB_FILE:-$BALLS_DB_DIR/${BALLS_ENV}.sqlite}
BALLS_PUBLIC=${BALLS_PUBLIC:-$BALLS_ROOT/public}

# HTMX defaults
BALLS_HTMX=${BALLS_HTMX:-1}

# Secrets (override via environment or .env)
BALLS_SECRET=${BALLS_SECRET:-changeme-secret}
